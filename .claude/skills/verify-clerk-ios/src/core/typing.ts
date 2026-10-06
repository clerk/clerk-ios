export interface FocusedField {
  type(text: string): Promise<void>;
  valueIfReadable(): Promise<string | null>;
  refocus(): Promise<void>;
}

export interface Settle {
  readonly reads: number;
  wait(): Promise<unknown>;
}

async function stayedEmpty(field: FocusedField, settle: Settle): Promise<boolean> {
  for (let read = 0; read < settle.reads; read += 1) {
    if (read > 0) await settle.wait();
    if ((await field.valueIfReadable()) !== '') return false;
  }
  return true;
}

export async function typeConfirmed(field: FocusedField, text: string, settle: Settle): Promise<void> {
  await field.type(text);
  if (text === '' || !(await stayedEmpty(field, settle))) return;
  await field.refocus();
  await field.type(text);
  if (await stayedEmpty(field, settle)) throw new Error('the text never reached the field: it was typed twice, and the focused field still reads empty');
}
