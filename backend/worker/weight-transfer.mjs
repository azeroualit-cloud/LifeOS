const parts=date=>Object.fromEntries(new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Rome',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date).filter(p=>p.type!=='literal').map(p=>[p.type,p.value]));
export function romeInput(date=new Date()) {const p=parts(date);return `${p.year}-${p.month}-${p.day}T${p.hour}:${p.minute}`;}
export function romeTimestamp(value){
 if(!/^20\d\d-(0[1-9]|1[0-2])-\d\dT[0-2]\d:[0-5]\d$/.test(value))throw Error('Data della pesata non valida.');
 const [y,m,d,h,n]=value.split(/[-T:]/).map(Number),naive=Date.UTC(y,m-1,d,h,n);let guess=naive;
 for(let i=0;i<3;i++){const p=parts(new Date(guess)),represented=Date.UTC(Number(p.year),Number(p.month)-1,Number(p.day),Number(p.hour),Number(p.minute));guess-=represented-naive;}
 if(romeInput(new Date(guess))!==value)throw Error('Questo orario non è valido a Roma. Scegli un altro orario.');
 return guess;
}
export function weightLink(kilograms,value,id,now=new Date()){
 const weight=Number(kilograms),at=romeTimestamp(value);
 if(!Number.isFinite(weight)||weight<=0||weight>500||at>now.getTime()||!/^\p{ASCII_Hex_Digit}{8}-\p{ASCII_Hex_Digit}{4}-\p{ASCII_Hex_Digit}{4}-\p{ASCII_Hex_Digit}{4}-\p{ASCII_Hex_Digit}{12}$/u.test(id))throw Error('Controlla peso e data della pesata.');
 const url=new URL('lifeos://weight');url.search=new URLSearchParams({id,kg:String(weight),at:String(at)}).toString();return url.href;
}
