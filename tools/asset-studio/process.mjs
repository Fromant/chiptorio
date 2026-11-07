import { spawn } from 'node:child_process';
import { mkdir, appendFile } from 'node:fs/promises';
import path from 'node:path';

/** Full logs on disk, bounded failure excerpts in the UI/CLI. No shell interpolation. */
export async function processLog(executable,args,{cwd,log,timeout=1800000}={}) {
  await mkdir(path.dirname(log),{recursive:true});
  await appendFile(log,`\n${new Date().toISOString()} ${JSON.stringify([executable,...args])}\n`);
  return new Promise((resolve,reject)=>{
    const child=spawn(executable,args,{cwd,windowsHide:true,shell:false,stdio:['ignore','pipe','pipe']});
    let tail='',writes=Promise.resolve(),timedOut=false;
    const timer=setTimeout(()=>{timedOut=true;child.kill();},timeout);
    const output=bytes=>{tail=(tail+bytes.toString()).slice(-3000);writes=writes.then(()=>appendFile(log,bytes));};
    child.stdout.on('data',output);child.stderr.on('data',output);
    child.once('error',error=>{clearTimeout(timer);reject(error);});
    child.once('close',async code=>{clearTimeout(timer);try{await writes;if(code!==0||timedOut)throw new Error(`${timedOut?'Timed out':`Process exited ${code}`}\n${tail}\nLog: ${log}`);resolve();}catch(error){reject(error);}});
  });
}
