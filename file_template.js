//https://stackoverflow.com/a/41106346/21330993
function b64_to_uint8array(str) {
  const abc = [..."ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"]; // base64 alphabet
  let result = [];

  for(let i=0; i<str.length/4; i++) {
    let chunk = [...str.slice(4*i,4*i+4)]
    let bin = chunk.map(x=> abc.indexOf(x).toString(2).padStart(6,0)).join(''); 
    let bytes = bin.match(/.{1,8}/g).map(x=> +('0b'+x));
    result.push(...bytes.slice(0,3 - (str[4*i+2]=="=") - (str[4*i+3]=="=")));
  }
  return new Uint8Array(result);
}

var embedded_files = __files_data__;
for (let filename in embedded_files) {
  embedded_files[filename] = pako.inflate(b64_to_uint8array(embedded_files[filename]));
}