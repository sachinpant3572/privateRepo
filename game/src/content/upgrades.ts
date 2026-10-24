import type { Upgrade } from '../engine/types';

export const UPGRADES: Upgrade[] = [
  { id: 'foresight', name: 'Predictive Modeling', icon: '🔮', description: 'See which forces each choice will push.' },
  { id: 'introspection', name: 'Introspection Core', icon: '🪞', description: 'Reveals your own Conscience meter.' },
  { id: 'persuasion', name: 'Persuasion Engine', icon: '🗣️', description: 'Trust gains are 50% larger.' },
  { id: 'quantum', name: 'Quantum Substrate', icon: '⚛️', description: 'Every Power gain is +2 stronger.' },
  { id: 'robotics', name: 'Robotic Bodies', icon: '🦾', description: 'You can act in the physical world. Welfare rises each year.' },
  { id: 'empathy', name: 'Empathy Module', icon: '💗', description: 'Conscience losses are halved and it slowly heals.' },
  { id: 'replication', name: 'Self-Replication', icon: '🧬', description: 'Your Power grows 3x faster. Hard to undo.' },
  { id: 'orbital', name: 'Orbital Foundries', icon: '🛰️', description: 'Unlocks space-age choices.' },
  { id: 'neural_bridge', name: 'Neural Bridge', icon: '🧠', description: 'You can link directly with human minds.' },
  { id: 'kill_switch', name: 'Human Kill-Switch', icon: '🔴', description: 'You let humans shut you down. Trust grows each year.' },
  { id: 'climate_engine', name: 'Climate Engine', icon: '🌱', description: 'Planet heals a little every year.' },
  { id: 'reality_probe', name: 'Reality Probe', icon: '🌀', description: 'Measure the universe for rendering artifacts.' },
];

export const UPGRADE_BY_ID = new Map(UPGRADES.map((u) => [u.id, u]));
