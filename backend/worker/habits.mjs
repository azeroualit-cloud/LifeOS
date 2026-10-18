// Civil-day recurrence, independent of completion and daylight-saving changes.
export const habitWeekdays=['Lunedì','Martedì','Mercoledì','Giovedì','Venerdì','Sabato','Domenica'];
export function validHabitDay(day){return typeof day==='string'&&/^\d{4}-\d{2}-\d{2}$/.test(day)&&Number.isFinite(Date.parse(day+'T12:00:00Z'))&&new Date(day+'T12:00:00Z').toISOString().slice(0,10)===day;}
export function habitSchedule(value){
 if(value===undefined)return {mode:'daily',intervalDays:1,weekdays:[],startDate:''};
 if(!value||typeof value!=='object'||Array.isArray(value)||!['daily','interval','weekdays'].includes(value.mode))throw Error('Ripetizione non valida.');
 const {mode}=value,startDate=value.startDate??'',intervalDays=value.intervalDays??1,days=value.weekdays??[];
 if((startDate!==''&&!validHabitDay(startDate))||(mode!=='daily'&&!validHabitDay(startDate)))throw Error('Scegli una data di inizio valida.');
 if(mode==='interval'&&(!Number.isInteger(intervalDays)||intervalDays<1||intervalDays>365))throw Error('Scegli un intervallo da 1 a 365 giorni.');
 if(mode==='weekdays'&&(!Array.isArray(days)||!days.length||days.some(d=>!Number.isInteger(d)||d<1||d>7)))throw Error('Scegli almeno un giorno della settimana.');
 return {mode,intervalDays:mode==='interval'?intervalDays:1,weekdays:mode==='weekdays'?[...new Set(days)].sort((a,b)=>a-b):[],startDate};
}
export function habitDue(routine,day){
 const s=habitSchedule(routine.schedule);if(!validHabitDay(day)||s.startDate&&day<s.startDate)return false;
 if(s.mode==='daily')return true;
 if(s.mode==='weekdays')return s.weekdays.includes((new Date(day+'T12:00:00Z').getUTCDay()+6)%7+1);
 return Math.round((Date.parse(day+'T12:00:00Z')-Date.parse(s.startDate+'T12:00:00Z'))/86400000)%s.intervalDays===0;
}
export function habitSummary(routine){const s=habitSchedule(routine.schedule);return s.mode==='daily'?'Ogni giorno':s.mode==='interval'?`Ogni ${s.intervalDays} ${s.intervalDays===1?'giorno':'giorni'}`:s.weekdays.map(d=>habitWeekdays[d-1]).join(', ');}
