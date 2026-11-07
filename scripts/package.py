#!/usr/bin/env python3
"""Assemble a native KOReader plugin using the unmodified Khromium HF engine/runtime."""
from pathlib import Path
import argparse,hashlib,json,struct,tempfile,zipfile,shutil
p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1]
def digest(b):return hashlib.sha256(b).hexdigest()
def patch(data):
    data=bytearray(data);assert data[:6]==b'\x7fELF\x01\x01'
    offset=struct.unpack_from('<I',data,28)[0];size,count=struct.unpack_from('<HH',data,42)
    for i in range(count):
        h=struct.unpack_from('<8I',data,offset+i*size)
        if h[0]==3:
            old=bytes(data[h[1]:h[1]+h[4]]).split(b'\0',1)[0]
            assert old==b'/mnt/us/khromiumld.so',old
            new=b'/mnt/us/kohromiumld.so\0';assert len(new)<=h[4]
            data[h[1]:h[1]+h[4]]=new.ljust(h[4],b'\0');return bytes(data)
    raise ValueError('No ELF interpreter')
with tempfile.TemporaryDirectory(prefix='kohromium-package-') as temp:
    stage=Path(temp);app=stage/'koreader/plugins/kohromium.koplugin'
    shutil.copytree(root/'plugin/kohromium.koplugin',app,ignore=shutil.ignore_patterns('state','*.log','*.core'))
    (app/'engine.sh').chmod(0o755) # Also works from source ZIPs without executable mode bits.
    with zipfile.ZipFile(a.base) as base:
        loader=stage/'kohromiumld.so';loader.write_bytes(base.read('khromiumld.so'));loader.chmod(0o755)
        for info in base.infolist():
            prefix='extensions/khromium/'
            if info.is_dir() or not info.filename.startswith(prefix):continue
            rel=Path(info.filename[len(prefix):]);assert '..' not in rel.parts
            if rel.parts[0] not in ('engine','runtime','licenses'):continue
            dest=app/rel;dest.parent.mkdir(parents=True,exist_ok=True)
            data=base.read(info)
            if rel.name in ('chromium-headless-shell','chrome_crashpad_handler'):data=patch(data)
            dest.write_bytes(data);dest.chmod(0o755 if rel.parts[0]=='engine' and rel.suffix=='' else 0o644)
        provenance=json.loads(base.read(prefix+'manifest.json'))
    for name in ('README.md','LICENSE','VALIDATION.md','THIRD_PARTY_NOTICES.md'):
        shutil.copyfile(root/name,app/name)
    with zipfile.ZipFile(app/'KOhromium-source.zip','w',zipfile.ZIP_DEFLATED) as source:
        for path in sorted(root.rglob('*')):
            if path.is_file() and not any(s in ('build','.git','state','__pycache__') for s in path.relative_to(root).parts) and path.suffix not in ('.zip','.pyc','.core'):
                source.write(path,path.relative_to(root))
    manifest={k:provenance[k] for k in ('engine','engine_package','engine_source','engine_deb_sha256','common_deb_sha256','runtime','kernel_abi_note')}
    manifest.update(name='KOhromium',version='156.0 HF Alpha 1',frontend='Native KOReader Lua plugin; no GTK2/X11 frontend',target='PW4 / hard-float firmware 5.17.1; KOReader v2026.07.1 APIs tested on desktop',interpreter='/mnt/us/kohromiumld.so',hardware_tested=False,sandbox=False,ai_assisted=True,release_stage='alpha')
    (app/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (stage/'INSTALL.txt').write_text('KOhromium 156.0 HF Alpha 1\n\nExtract into the Kindle USB root: kohromiumld.so at the root, plugin at koreader/plugins/kohromium.koplugin. Restart KOReader, open its main menu and choose KOhromium > Open browser. Requires an already jailbroken PW4, hard-float firmware 5.17.1, and KOReader. No KUAL launcher or GTK2 app is used. Other KOReader install locations need the plugin folder moved into that installation\'s plugins directory; the loader must stay at /mnt/us/kohromiumld.so.\n\nExperimental native KOReader integration; no physical Kindle test yet. Developed with AI assistance. Chromium runs without its sandbox. Read the included README and validation notes.\n')
    (stage/'SHA256SUMS.txt').write_text(''.join(digest(p.read_bytes())+'  '+str(p.relative_to(stage))+'\n' for p in sorted(stage.rglob('*')) if p.is_file()))
    a.output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(a.output,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as out:
        for path in sorted(stage.rglob('*')):
            if path.is_file():out.write(path,path.relative_to(stage))
    with zipfile.ZipFile(a.output) as out:assert out.testzip() is None
    print(json.dumps(dict(output=str(a.output),bytes=a.output.stat().st_size,sha256=digest(a.output.read_bytes())),indent=2))
