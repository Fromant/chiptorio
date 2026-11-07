/** Compatibility guard: the former renderer wrote canonical models and installed art. */
if(process.argv.some(arg=>arg.includes('qln-terminal'))){
  throw new Error('QLN Terminal is approved and protected; explicitly unlock it in Asset Studio before creating a staged candidate.');
}
throw new Error('Legacy batch renderer disabled. Use npm run pipeline -- build --batch=done-5, or Asset Studio. Draft/candidate jobs never install; publication requires visual approval and isolated validation.');
