export function tryLoadLocal(key) {
  let val = localStorage.getItem(key);
  if (val === null) {
    return null;
  }
  try {
    return JSON.parse(val);
  } catch (e) {
    // console.log(e);
    return null;
  }
}

export function trySaveLocal(key, val) {
  try {
    localStorage.setItem(key, JSON.stringify(val));
  } catch (e) {
    // console.log(e);
    return;
  }
}