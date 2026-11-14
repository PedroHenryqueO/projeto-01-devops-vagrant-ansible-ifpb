#!/usr/bin/env python3
"""Verifica os discos sem alterá-los; aceita discos vazios ou o LVM do projeto."""
import json, os, subprocess, sys
def run(*args):
    return subprocess.check_output(args,text=True).strip()
def fail(message):
    raise SystemExit("SEGURANCA: "+message)
expected=json.loads(sys.argv[1])
tree=json.loads(run("lsblk","-b","-J","-o","PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL"))["blockdevices"]
root=run("findmnt","-n","-o","SOURCE","/")
ancestors=set(run("lsblk","-s","-r","-n","-p","-o","PATH",root).splitlines())
pvs=json.loads(run("pvs","--reportformat","json","-o","pv_name,vg_name"))["report"][0]["pv"]
pvmap={os.path.realpath(p["pv_name"]):p["vg_name"].strip() for p in pvs}
selected=[]
for serial in expected:
    matches=[d for d in tree if d.get("serial")==serial]
    if len(matches)!=1: fail("Identidade ausente/duplicada: "+serial)
    d=matches[0]; path=d["path"]
    if path in ancestors or d["type"]!="disk" or int(d["size"])!=10737418240:
        fail("Tamanho/tipo/ancestral do SO divergente: "+path)
    if any(d.get("mountpoints") or []): fail("Disco diretamente montado: "+path)
    signatures=json.loads(run("wipefs","-n","-J",path)).get("signatures",[])
    if d.get("fstype") is None:
        if signatures or d.get("children") or path in pvmap:
            fail("Dados/particoes inesperados: "+path)
    elif d["fstype"]=="LVM2_member" and pvmap.get(os.path.realpath(path))=="dados":
        if any(s["type"]!="LVM2_member" for s in signatures): fail("Assinatura extra: "+path)
        for child in d.get("children",[]):
            if child["path"]!="/dev/mapper/dados-ifpb" or child["type"]!="lvm" or child.get("fstype") not in (None,"ext4") or child.get("children"):
                fail("Volume/assinatura inesperada: "+path)
            if any(m not in (None,"/dados") for m in child.get("mountpoints",[])):
                fail("Montagem inesperada do LV")
    else: fail("Assinatura/PV nao autorizado: "+path)
    selected.append(path)
if len(set(selected))!=3: fail("Esperados exatamente tres discos distintos")
if any(v=="dados" and p not in selected for p,v in pvmap.items()): fail("VG inclui disco externo")
lvs=json.loads(run("lvs","--reportformat","json","--units","b","--nosuffix","-o","vg_name,lv_name,lv_size"))["report"][0]["lv"]
for lv in lvs:
    if lv["vg_name"].strip()=="dados" and (lv["lv_name"].strip()!="ifpb" or int(float(lv["lv_size"]))!=16106127360):
        fail("LV inesperado em dados")
print(json.dumps({"devices":selected,"root":root,"serials":expected,"safe":True}))
