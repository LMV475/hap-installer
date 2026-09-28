export enum Breakpoint {
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
}

export const BREAKPOINT_SM: number = 600;
export const BREAKPOINT_MD: number = 840;

export function breakpointFromWidth(widthVp: number): Breakpoint {
  if (widthVp < BREAKPOINT_SM) {
    return Breakpoint.SM;
  }
  if (widthVp < BREAKPOINT_MD) {
    return Breakpoint.MD;
  }
  return Breakpoint.LG;
}

export function syncBreakpoint(widthVp: number): Breakpoint {
  const bp: Breakpoint = breakpointFromWidth(widthVp);
  AppStorage.setOrCreate<Breakpoint>('currentBreakpoint', bp);
  return bp;
}
