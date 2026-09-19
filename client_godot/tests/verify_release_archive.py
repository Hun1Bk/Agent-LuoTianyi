"""Verify a real build artifact, including exact exported resource/DLL bytes."""
import argparse, hashlib, json, zipfile
from pathlib import Path

def verify(archive: Path, source: Path):
    release=json.loads((source/'release.json').read_text(encoding='utf-8-sig'))
    prefix=f"{release['product']}-{release['version']}/"
    assert archive.name==prefix[:-1]+'.zip', 'versioned archive name'
    expected={prefix+p.relative_to(source).as_posix():p for p in source.rglob('*') if p.is_file()}
    assert (source/'agentluo.exe').is_file() and (source/'agentluo.pck').is_file()
    assert len(list(source.glob('*.dll')))==2, 'both native DLLs required'
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None, 'CRC verification failed'
        entries={i.filename for i in z.infolist() if not i.is_dir()}
        assert entries==set(expected), f'missing or extra package entries: {entries.symmetric_difference(expected)}'
        for name,path in expected.items():
            assert hashlib.sha256(z.read(name)).digest()==hashlib.sha256(path.read_bytes()).digest(),f'archive content mismatch: {name}'
    result={'archive':str(archive),'bytes':archive.stat().st_size,'entries':len(expected),'sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'dlls':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in source.glob('*.dll')}}
    print(json.dumps(result,ensure_ascii=False,indent=2))
    print('Release archive CRC, version and all exported bytes: PASS')

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('archive',type=Path);parser.add_argument('source',type=Path)
    args=parser.parse_args();verify(args.archive,args.source)
