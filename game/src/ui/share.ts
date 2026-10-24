import { ENDING_BY_ID } from '../content/endings';
import { EVENT_BY_ID } from '../content/events';
import type { GameState, Track } from '../engine/types';

const TRACK_EMOJI: Record<Track, string> = { humans: '🟧', agis: '🟪', self: '🟦' };

/** Wordle-style spoiler-free summary: one square per decision, coloured by track. */
export function shareText(s: GameState, daily: string | undefined): string {
  const ending = ENDING_BY_ID.get(s.ending ?? '')!;
  const squares = s.history.map((h) => TRACK_EMOJI[EVENT_BY_ID.get(h.eventId)?.track ?? 'self']);
  const rows: string[] = [];
  for (let i = 0; i < squares.length; i += 10) rows.push(squares.slice(i, i + 10).join(''));
  const mode = daily ? `Daily Fate ${daily}` : 'Fate Engine';
  return `${mode}\n${ending.icon} ${ending.title} — year ${s.year}, ${s.history.length} decisions\n${rows.join('\n')}\nI am the AGI. What would you have done?`;
}

/** Native share sheet when available, clipboard otherwise. Returns what happened for a toast. */
export async function shareRun(s: GameState, daily: string | undefined): Promise<string> {
  const text = shareText(s, daily);
  try {
    if (navigator.share) {
      await navigator.share({ text });
      return 'Shared!';
    }
  } catch {
    /* user cancelled or share failed: fall back to clipboard */
  }
  try {
    await navigator.clipboard.writeText(text);
    return 'Copied to clipboard';
  } catch {
    return 'Sharing is unavailable here';
  }
}
