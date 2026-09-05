import assert from 'node:assert/strict';
const day=process.argv[2] ?? crypto.randomUUID();
const now=Date.now();
const rpc=async(method,args)=>{
  const response=await fetch('http://127.0.0.1:8797',{method:'POST',body:JSON.stringify({method,day,args})});
  assert.equal(response.status,200,await response.clone().text());
  return response.json();
};
if(process.argv[2]) {
  const result=await rpc('snapshot',{now});assert.equal(result.global,7);
  console.log(JSON.stringify({day,restoredGlobal:result.global,persistence:'passed'}));
} else {
  const values=await Promise.all(Array.from({length:100},(_,i)=>rpc('reserve',{
    id:crypto.randomUUID(),subject:`user-${i%10}`,bucket:'chat',limit:2,globalLimit:7,now
  })));
  const accepted=values.filter(x=>x.ok);assert.equal(accepted.length,7);
  await Promise.all(Array.from({length:10},()=>rpc('refund',{id:accepted[0].reservationID})));
  assert.equal((await rpc('snapshot',{now})).global,6);
  const next=await rpc('reserve',{id:crypto.randomUUID(),subject:'new',bucket:'image',limit:1,globalLimit:7,now});
  assert.equal(next.ok,true);
  assert.equal((await rpc('snapshot',{now})).global,7);
  console.log(JSON.stringify({day,requests:100,accepted:7,repeatedRefunds:10,globalAfterRefund:6,finalGlobal:7}));
}
