export type ImportRecord={companyName:string;website?:string;description?:string;assetPath?:string;boothIds?:string[];tags?:string[]}
export function validateImport(value:unknown){
  const errors:string[]=[]
  if(!Array.isArray(value)||value.length===0)return ['The file must contain a non-empty JSON array.']
  const names=new Set<string>(),booths=new Set<string>()
  value.forEach((raw,index)=>{const row=raw as Partial<ImportRecord>,label=`Row ${index+1}`;const name=typeof row.companyName==='string'?row.companyName.trim():''
    if(!name)errors.push(`${label}: companyName is required.`);else if(names.has(name.toLowerCase()))errors.push(`${label}: duplicate companyName “${name}”.`);else names.add(name.toLowerCase())
    if(row.website&& !/^https?:\/\//i.test(row.website))errors.push(`${label}: website must start with http:// or https://.`)
    if(row.boothIds!==undefined&&!Array.isArray(row.boothIds))errors.push(`${label}: boothIds must be an array.`);else (row.boothIds??[]).forEach(id=>{const normalized=String(id).trim().toUpperCase();if(!/^[A-Z0-9#.-]{2,12}$/.test(normalized))errors.push(`${label}: invalid Booth ID “${id}”.`);else if(booths.has(normalized))errors.push(`${label}: duplicate Booth ID “${normalized}”.`);else booths.add(normalized)})
    if(row.tags!==undefined&&!Array.isArray(row.tags))errors.push(`${label}: tags must be an array.`)
  });return errors
}
