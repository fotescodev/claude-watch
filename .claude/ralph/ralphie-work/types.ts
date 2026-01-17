
export enum VariantType {
  TERMINAL = 'TERMINAL',
  MASCOT = 'MASCOT',
  ABSTRACT = 'ABSTRACT'
}

export enum FlowStep {
  ICON = 'ICON',
  PAIRING = 'PAIRING',
  COMPLICATION = 'COMPLICATION',
  INTERFACE = 'INTERFACE',
  NOTIFICATION = 'NOTIFICATION',
  VOICE = 'VOICE'
}

export enum PermissionMode {
  NORMAL = 'NORMAL',
  AUTO_ACCEPT = 'AUTO_ACCEPT',
  PLAN = 'PLAN'
}

export enum HubCategory {
  DESIGNER = 'DESIGNER',
  FOUNDATIONS = 'FOUNDATIONS',
  JOURNEYS = 'JOURNEYS',
  FLOWS = 'FLOWS',
  RALPHIE = 'RALPHIE',
  PRD = 'PRD'
}

export interface DesignVariant {
  id: VariantType;
  name: string;
  concept: string;
  accentColor: string;
  canvasColor: string;
}

export interface WatchSize {
  size: number;
  label: string;
  usage: string;
  shape: 'circle' | 'squircle';
}
