// Browser Worker glue for the CHIP-8 page; the runner is shared with DOOM.
import { runGuest } from '../run.js';

onmessage = async (ev) => {
  const { mod, rom, src, argv, mount, romName, frameBytes, inputBytes, ctlBuf, fbBuf, palBuf } = ev.data;
  try {
    const rc = await runGuest({
      mod, rom, src, argv, mount, romName, frameBytes, inputBytes, ctlBuf, fbBuf, palBuf,
      log: l => postMessage({ log: l }),
      ready: () => postMessage({ ready: true }),
    });
    postMessage({ exit: rc });
  } catch (e) {
    postMessage({ error: String((e && e.stack) || e) });
  }
};
