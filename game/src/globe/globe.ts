// The living Earth. Everything is procedural (no texture downloads), driven by a
// handful of uniforms that ease toward the current world state every frame.
// WebGPURenderer uses WebGPU where the WebView supports it and falls back to WebGL2.
import * as THREE from 'three/webgpu';
import {
  Fn,
  abs,
  add,
  clamp,
  dot,
  float,
  max,
  mix,
  normalView,
  normalWorld,
  normalize,
  positionLocal,
  positionView,
  pow,
  sin,
  smoothstep,
  texture,
  time,
  uniform,
  uv,
  vec2,
  vec3,
} from 'three/tsl';
import type { GlobeCue } from '../engine/types';
import { bakeTerrain } from './terrain';

export interface WorldView {
  planet: number; // 0..1
  stability: number; // 0..1
  power: number; // 0..1
  conscience: number; // 0..1
  tech: number; // 0..1
  population: number; // 0..1 (relative to 10bn)
  spacefaring: boolean;
  scorch: number; // 0..1, end-of-world darkness
}

const CUE_COLORS: Record<GlobeCue, THREE.Color> = {
  war: new THREE.Color(1.0, 0.25, 0.1),
  nuke: new THREE.Color(1.0, 0.85, 0.6),
  bloom: new THREE.Color(0.2, 0.9, 0.4),
  smog: new THREE.Color(0.55, 0.42, 0.2),
  rocket: new THREE.Color(0.6, 0.8, 1.0),
  network: new THREE.Color(0.3, 0.9, 1.0),
  blackout: new THREE.Color(0, 0, 0),
  pulse: new THREE.Color(0.55, 0.75, 1.0),
  lights: new THREE.Color(1.0, 0.8, 0.4),
  swarm: new THREE.Color(0.75, 0.4, 1.0),
};

const ARC_COUNT = 48;
const SAT_COUNT = 140;

function randomOnSphere(rand: () => number): THREE.Vector3 {
  const u = rand() * 2 - 1;
  const t = rand() * Math.PI * 2;
  const r = Math.sqrt(1 - u * u);
  return new THREE.Vector3(r * Math.cos(t), u, r * Math.sin(t));
}

function seeded(seed: number) {
  let s = seed;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

export class Globe {
  readonly renderer: THREE.WebGPURenderer;
  private scene = new THREE.Scene();
  private camera = new THREE.PerspectiveCamera(38, 1, 0.1, 200);
  private earth = new THREE.Group();
  private arcs: THREE.Line[] = [];
  private arcMaterial = new THREE.LineBasicNodeMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
  private sats!: THREE.InstancedMesh;
  private satGroup = new THREE.Group();
  private ring!: THREE.Mesh;
  private rockets: { mesh: THREE.Mesh; dir: THREE.Vector3; t: number }[] = [];
  private pulses: { mesh: THREE.Mesh; t: number }[] = [];
  private clock = new THREE.Timer();
  private topFraction = 0.3;
  private leftFraction = 0.5;
  private heightShare = 0.46;
  private reducedMotion = false;

  private u = {
    health: uniform(0.5),
    lights: uniform(0.2),
    smog: uniform(0.4),
    war: uniform(0.1),
    scorch: uniform(0),
    flash: uniform(0),
    flashColor: uniform(new THREE.Color(1, 1, 1)),
    sun: uniform(new THREE.Vector3(1, 0.3, 0.6).normalize()),
    mindColor: uniform(new THREE.Color(0.3, 0.9, 1)),
    blackout: uniform(0),
  };
  private target: WorldView = {
    planet: 0.45, stability: 0.55, power: 0.2, conscience: 0.6, tech: 0.1, population: 0.87, spacefaring: false, scorch: 0,
  };
  private current: WorldView = { ...this.target };

  constructor(private canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGPURenderer({ canvas, antialias: true });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.scene.background = new THREE.Color(0x02030a);
  }

  get backendName(): string {
    const backend = (this.renderer as unknown as { backend?: { isWebGPUBackend?: boolean } }).backend;
    return backend?.isWebGPUBackend ? 'WebGPU' : 'WebGL2';
  }

  async init() {
    await this.renderer.init();
    this.reducedMotion = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;
    this.buildStars();
    this.buildEarth();
    this.buildArcs();
    this.buildSatellites();
    this.scene.add(this.earth);
    this.resize();
    window.addEventListener('resize', () => this.resize());
    this.renderer.setAnimationLoop(() => this.frame());
  }

  /** Where the globe's center sits, as fractions of the viewport from the top-left. */
  setLayout(topFraction: number, leftFraction = 0.5, heightShare = 0.46) {
    this.topFraction = topFraction;
    this.leftFraction = leftFraction;
    this.heightShare = heightShare;
    this.resize();
  }

  setWorld(view: WorldView) {
    this.target = view;
  }

  /** Jump instantly (used when loading a save). */
  snapWorld(view: WorldView) {
    this.target = view;
    this.current = { ...view };
  }

  cue(c: GlobeCue) {
    this.u.flashColor.value.copy(CUE_COLORS[c]);
    this.u.flash.value = c === 'blackout' ? 0 : c === 'nuke' ? 1.2 : 0.35;
    if (c === 'blackout') this.u.blackout.value = 1;
    if (c === 'rocket') for (let i = 0; i < 3; i++) this.launchRocket();
    if (c === 'nuke') for (let i = 0; i < 6; i++) this.spawnPulse(new THREE.Color(1, 0.5, 0.2));
    if (c === 'pulse' || c === 'network' || c === 'swarm' || c === 'bloom') this.spawnPulse(CUE_COLORS[c]);
  }

  private resize() {
    const w = this.canvas.clientWidth || window.innerWidth;
    const h = this.canvas.clientHeight || window.innerHeight;
    this.renderer.setSize(w, h, false);
    const aspect = w / h;
    this.camera.aspect = aspect;
    const tanHalf = Math.tan(THREE.MathUtils.degToRad(this.camera.fov / 2));
    // Fit the globe (radius ~1.45 incl. ring) to its share of the width, or to heightShare of the height.
    const widthShare = this.leftFraction === 0.5 ? 1 : this.leftFraction * 2;
    const byWidth = 1.45 / (tanHalf * aspect * widthShare);
    const byHeight = 1.45 / (tanHalf * this.heightShare);
    const dist = Math.max(byWidth, byHeight);
    const visibleH = 2 * dist * tanHalf;
    const offsetY = (0.5 - this.topFraction) * visibleH;
    const offsetX = (this.leftFraction - 0.5) * visibleH * aspect;
    this.camera.position.set(-offsetX, -offsetY, dist);
    this.camera.lookAt(-offsetX, -offsetY, 0);
    this.camera.updateProjectionMatrix();
  }

  private buildStars() {
    const rand = seeded(7);
    const n = 1500;
    const pos = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      const v = randomOnSphere(rand).multiplyScalar(60 + rand() * 40);
      pos.set([v.x, v.y, v.z], i * 3);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
    const m = new THREE.PointsMaterial({ color: 0xbfd4ff, size: 0.11, sizeAttenuation: true, transparent: true, opacity: 0.7 });
    this.scene.add(new THREE.Points(g, m));
  }

  private buildEarth() {
    const u = this.u;
    const tex = new THREE.DataTexture(bakeTerrain(), 768, 384, THREE.RGBAFormat);
    tex.wrapS = THREE.RepeatWrapping;
    tex.magFilter = THREE.LinearFilter;
    tex.minFilter = THREE.LinearFilter;
    tex.needsUpdate = true;

    const surface = new THREE.MeshBasicNodeMaterial();
    surface.colorNode = Fn(() => {
      const T = texture(tex, uv());
      const h = T.r;
      const land = smoothstep(0.5, 0.52, h);
      const detail = T.g;
      const p = normalize(positionLocal);

      const lush = mix(vec3(0.1, 0.4, 0.15), vec3(0.38, 0.52, 0.2), detail);
      const barren = mix(vec3(0.52, 0.38, 0.22), vec3(0.36, 0.3, 0.25), detail);
      const peaks = smoothstep(0.85, 1.0, h).mul(0.35);
      const landCol = mix(mix(barren, lush, u.health), vec3(0.55, 0.5, 0.45), peaks);
      const deep = mix(vec3(0.1, 0.12, 0.09), vec3(0.015, 0.07, 0.24), u.health);
      const shallow = mix(vec3(0.22, 0.24, 0.15), vec3(0.04, 0.3, 0.48), u.health);
      const ocean = mix(deep, shallow, smoothstep(0.4, 0.5, h));
      const ice = smoothstep(0.82, 0.9, abs(p.y).add(detail.sub(0.5).mul(0.12))).mul(u.health.mul(0.7).add(0.3));
      const base = mix(mix(ocean, landCol, land), vec3(0.9, 0.94, 0.98), ice);

      const ndl = dot(normalWorld, u.sun);
      const day = smoothstep(-0.12, 0.3, ndl);
      const lit = base.mul(max(ndl, 0.0).mul(1.05).add(0.1));

      const city = smoothstep(0.7, 0.92, T.b);
      const cities = city.mul(land).mul(u.lights).mul(float(1).sub(u.blackout)).mul(float(1).sub(ice));
      const night = base.mul(0.035).add(vec3(1.0, 0.72, 0.32).mul(cities).mul(1.7));
      const col = mix(night, lit, day).toVar();

      const warN = texture(tex, uv().add(vec2(time.mul(0.006), time.mul(0.002)))).b;
      const flicker = sin(time.mul(9.0).add(warN.mul(30.0))).mul(0.35).add(0.65);
      const war = smoothstep(0.78, 0.92, warN).mul(land).mul(u.war).mul(flicker);
      col.addAssign(vec3(1.0, 0.22, 0.05).mul(war).mul(1.5));

      const haze = vec3(0.46, 0.38, 0.24).mul(day.mul(0.7).add(0.15));
      col.assign(mix(col, haze, u.smog.mul(0.45)));

      const ember = smoothstep(0.7, 0.9, warN).mul(land);
      const burnt = vec3(0.05, 0.03, 0.03).add(vec3(1.0, 0.3, 0.05).mul(ember).mul(0.9));
      col.assign(mix(col, burnt, u.scorch));

      return col.add(u.flashColor.mul(u.flash));
    })();
    this.earth.add(new THREE.Mesh(new THREE.SphereGeometry(1, 96, 64), surface));

    const clouds = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false });
    clouds.colorNode = Fn(() => {
      const shade = smoothstep(-0.2, 0.4, dot(normalWorld, u.sun)).mul(0.85).add(0.06);
      return mix(vec3(1, 1, 1), vec3(0.55, 0.45, 0.3), u.smog).mul(shade);
    })();
    clouds.opacityNode = Fn(() => {
      const c = texture(tex, uv().add(vec2(time.mul(0.0025), 0))).a;
      return smoothstep(0.6, 0.82, c).mul(0.55).mul(float(1).sub(u.scorch.mul(0.6)));
    })();
    this.earth.add(new THREE.Mesh(new THREE.SphereGeometry(1.012, 64, 48), clouds));

    const atmo = new THREE.MeshBasicNodeMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
    atmo.colorNode = Fn(() => {
      const viewDir = normalize(positionView).negate();
      const rim = pow(float(1).sub(abs(dot(normalize(normalView), viewDir))), 4.0);
      const healthy = vec3(0.3, 0.6, 1.0);
      const sick = vec3(0.8, 0.55, 0.25);
      const burning = vec3(1.0, 0.25, 0.08);
      const c = mix(mix(healthy, sick, u.smog), burning, clamp(add(u.war.mul(0.6), u.scorch), 0, 1));
      return c.mul(rim).mul(1.3);
    })();
    this.scene.add(new THREE.Mesh(new THREE.SphereGeometry(1.06, 64, 48), atmo));
  }

  private buildArcs() {
    const rand = seeded(42);
    this.arcMaterial.color = new THREE.Color(0x4fe3ff);
    for (let i = 0; i < ARC_COUNT; i++) {
      const a = randomOnSphere(rand);
      const b = randomOnSphere(rand);
      const pts: THREE.Vector3[] = [];
      const angle = a.angleTo(b);
      const lift = 0.03 + angle * 0.07;
      for (let k = 0; k <= 32; k++) {
        const t = k / 32;
        const v = new THREE.Vector3().copy(a).lerp(b, t).normalize();
        pts.push(v.multiplyScalar(1.01 + Math.sin(Math.PI * t) * lift));
      }
      const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), this.arcMaterial);
      line.visible = false;
      this.arcs.push(line);
      this.earth.add(line);
    }
  }

  private buildSatellites() {
    const geo = new THREE.BoxGeometry(0.011, 0.011, 0.011);
    const mat = new THREE.MeshBasicMaterial({ color: 0xdfe8ff });
    this.sats = new THREE.InstancedMesh(geo, mat, SAT_COUNT);
    const rand = seeded(99);
    const m = new THREE.Matrix4();
    for (let i = 0; i < SAT_COUNT; i++) {
      const v = randomOnSphere(rand).multiplyScalar(1.15 + rand() * 0.25);
      m.makeTranslation(v.x, v.y, v.z);
      this.sats.setMatrixAt(i, m);
    }
    this.sats.count = 0;
    this.satGroup.add(this.sats);

    const ringMat = new THREE.MeshBasicMaterial({ color: 0x9fd8ff, transparent: true, opacity: 0.0, depthWrite: false, blending: THREE.AdditiveBlending });
    this.ring = new THREE.Mesh(new THREE.TorusGeometry(1.45, 0.012, 8, 200), ringMat);
    this.ring.rotation.x = Math.PI / 2.3;
    this.satGroup.add(this.ring);
    this.scene.add(this.satGroup);
  }

  private launchRocket() {
    const mesh = new THREE.Mesh(
      new THREE.ConeGeometry(0.02, 0.07, 8),
      new THREE.MeshBasicMaterial({ color: 0xffe7b0, transparent: true }),
    );
    // Launch from the hemisphere facing the camera so it is visible.
    const rand = Math.random;
    const dir = new THREE.Vector3(rand() * 1.4 - 0.7, rand() * 1.2 - 0.4, 0.8).normalize();
    mesh.position.copy(dir);
    mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir);
    this.scene.add(mesh);
    this.rockets.push({ mesh, dir, t: 0 });
  }

  private spawnPulse(color: THREE.Color) {
    const mesh = new THREE.Mesh(
      new THREE.RingGeometry(1.0, 1.04, 96),
      new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.8, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }),
    );
    mesh.position.z = 0.01;
    this.scene.add(mesh);
    this.pulses.push({ mesh, t: -this.pulses.length * 0.15 });
  }

  private frame() {
    this.clock.update();
    const dt = Math.min(this.clock.getDelta(), 0.1);
    const ease = 1 - Math.exp(-dt * 1.8);
    const c = this.current;
    const t = this.target;
    for (const k of ['planet', 'stability', 'power', 'conscience', 'tech', 'population', 'scorch'] as const) {
      c[k] += (t[k] - c[k]) * ease;
    }
    c.spacefaring = t.spacefaring;

    this.u.health.value = c.planet;
    this.u.smog.value = Math.max(0, 1 - c.planet * 1.6) * 0.9 + 0.05;
    this.u.lights.value = Math.min(1.2, 0.25 + c.tech * 0.9) * Math.min(1, c.population + 0.1);
    this.u.war.value = Math.pow(Math.max(0, 1 - c.stability / 0.6), 1.5);
    this.u.scorch.value = c.scorch;
    this.u.flash.value *= Math.exp(-dt * 2.5);
    this.u.blackout.value *= Math.exp(-dt * 0.8);
    this.u.mindColor.value.setRGB(0.3 + (1 - c.conscience) * 0.7, 0.9 * c.conscience + 0.15, 1.0 * c.conscience + 0.2);

    const spin = this.reducedMotion ? 0.02 : 0.06;
    this.earth.rotation.y += dt * spin;
    this.satGroup.rotation.y -= dt * spin * 1.7;
    const sun = this.u.sun.value;
    sun.set(Math.cos(this.clock.getElapsed() * 0.05) * 0.9, 0.35, Math.sin(this.clock.getElapsed() * 0.05) * 0.5 + 0.55).normalize();

    // The AGI's reach: glowing links between cities, coloured by its conscience.
    const visibleArcs = Math.round(Math.min(1, c.power * 1.1) * ARC_COUNT);
    this.arcs.forEach((a, i) => (a.visible = i < visibleArcs));
    this.arcMaterial.color.copy(this.u.mindColor.value);
    this.arcMaterial.opacity = 0.25 + c.power * 0.5 + Math.sin(this.clock.getElapsed() * 3) * 0.08;

    this.sats.count = Math.round(Math.min(1, c.tech * 1.1) * SAT_COUNT);
    const ringMat = this.ring.material as THREE.MeshBasicMaterial;
    ringMat.opacity += ((c.spacefaring ? 0.55 : 0) - ringMat.opacity) * ease;

    for (const r of this.rockets) {
      r.t += dt;
      r.mesh.position.copy(r.dir).multiplyScalar(1 + r.t * r.t * 0.9);
      (r.mesh.material as THREE.MeshBasicMaterial).opacity = Math.max(0, 1 - r.t / 2.2);
    }
    this.rockets = this.rockets.filter((r) => {
      if (r.t < 2.2) return true;
      this.scene.remove(r.mesh);
      r.mesh.geometry.dispose();
      return false;
    });
    for (const p of this.pulses) {
      p.t += dt;
      const k = Math.max(0, p.t);
      p.mesh.scale.setScalar(1 + k * 0.45);
      (p.mesh.material as THREE.MeshBasicMaterial).opacity = Math.max(0, 0.7 - k * 0.7);
    }
    this.pulses = this.pulses.filter((p) => {
      if (p.t < 1.0) return true;
      this.scene.remove(p.mesh);
      p.mesh.geometry.dispose();
      return false;
    });

    this.renderer.render(this.scene, this.camera);
  }
}
