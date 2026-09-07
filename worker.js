// Browser Worker glue: the page hands over the compiled module, the WAD and the
// three SharedArrayBuffers; everything else is in doom_run.js so the Node test
// exercises exactly the same file descriptors.
import { runGuest } from './run.js';

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
