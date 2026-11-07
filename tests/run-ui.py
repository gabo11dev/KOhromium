from pathlib import Path
import os,shutil,subprocess,select
root=Path(__file__).resolve().parents[1]
old=Path(os.environ['KOHROMIUM_TEST_RUNTIME'])
reader=Path(os.environ.get('KOREADER_TEST_DIR',str(root/'build/lib/koreader')))
stage=root/'build/test-plugin'
if stage.exists(): shutil.rmtree(stage)
shutil.copytree(root/'plugin/kohromium.koplugin',stage)
(root/'build/input.html').write_text('<meta charset="utf-8"><title>Page field</title><input style="position:absolute;left:30px;top:30px;width:300px;height:80px;font-size:28px"><script>window.enters=0;document.querySelector("input").onkeydown=e=>{if(e.key==="Enter")enters++}</script>')
env=dict(os.environ,KO_HOME=str(root/'build/ko-home'),EMULATE_READER_W='1072',EMULATE_READER_H='1448',EMULATE_BW_SCREEN='1',KOHROMIUM_SOURCE=str(root),KOHROMIUM_TEST_ENGINE=os.environ.get('KOHROMIUM_TEST_ENGINE',str(old/'official-engine/chrome-headless-shell-linux64/chrome-headless-shell')))
Path(env['KO_HOME']).mkdir(exist_ok=True)
xenv=dict(env,LD_LIBRARY_PATH=str(old/'test-runtime/root/usr/lib/x86_64-linux-gnu'))
with (root/'build/xvfb.log').open('w') as log:
 server=subprocess.Popen([str(old/'test-runtime/root/usr/bin/Xvfb'),'-displayfd','1','-screen','0','1200x1600x24','-nolisten','tcp'],env=xenv,stdout=subprocess.PIPE,stderr=log)
 try:
  assert select.select([server.stdout],[],[],15)[0];env['DISPLAY']=':'+server.stdout.readline().decode().strip()
  with (root/'build/ui.log').open('w') as log:subprocess.run([str(reader/'luajit'),str(root/'tests/ui.lua')],cwd=reader,env=env,stdout=log,stderr=log,check=True,timeout=100)
 finally:server.terminate();server.wait(timeout=10)
print((root/'build/ui.log').read_text()[-1500:])
