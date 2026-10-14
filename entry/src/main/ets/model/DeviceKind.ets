import { I18n } from '../utils/I18n';

/**
 * 设备类型表：key 为存储用标识，labelKey 为文案资源键，color 为图表/标签主题色。
 * 每个 key 对应一张 Q 版图标（entry/src/main/resources/base/media/dev_<key>.png）。
 *
 * 表里存的是资源键而不是文案：类型名要在切换语言后立刻变，
 * 而 $r() 走的是资源限定目录、只有冷启动才生效，所以这里只放 key，
 * 取值统一交给 I18n.t()（见 kindLabel）。
 */
export interface DeviceKind {
  key: string;
  labelKey: string;
  color: string;
}

export const DEVICE_KINDS: DeviceKind[] = [
  { key: 'phone', labelKey: 'kind_phone', color: '#4F8CFF' },
  { key: 'laptop', labelKey: 'kind_laptop', color: '#6C7BFF' },
  { key: 'tablet', labelKey: 'kind_tablet', color: '#38BDF8' },
  { key: 'desktop', labelKey: 'kind_desktop', color: '#64748B' },
  { key: 'monitor', labelKey: 'kind_monitor', color: '#14B8A6' },
  { key: 'tv', labelKey: 'kind_tv', color: '#F59E0B' },
  { key: 'projector', labelKey: 'kind_projector', color: '#8B5CF6' },
  { key: 'camera', labelKey: 'kind_camera', color: '#EF4444' },
  { key: 'actioncam', labelKey: 'kind_actioncam', color: '#FB923C' },
  { key: 'drone', labelKey: 'kind_drone', color: '#22C55E' },
  { key: 'headphone', labelKey: 'kind_headphone', color: '#A855F7' },
  { key: 'earbuds', labelKey: 'kind_earbuds', color: '#EC4899' },
  { key: 'speaker', labelKey: 'kind_speaker', color: '#F43F5E' },
  { key: 'smartspeaker', labelKey: 'kind_smartspeaker', color: '#06B6D4' },
  { key: 'mic', labelKey: 'kind_mic', color: '#84CC16' },
  { key: 'watch', labelKey: 'kind_watch', color: '#10B981' },
  { key: 'band', labelKey: 'kind_band', color: '#2DD4BF' },
  { key: 'vr', labelKey: 'kind_vr', color: '#7C3AED' },
  { key: 'console', labelKey: 'kind_console', color: '#334155' },
  { key: 'handheld', labelKey: 'kind_handheld', color: '#DB2777' },
  { key: 'keyboard', labelKey: 'kind_keyboard', color: '#475569' },
  { key: 'mouse', labelKey: 'kind_mouse', color: '#94A3B8' },
  { key: 'drawing', labelKey: 'kind_drawing', color: '#0891B2' },
  { key: 'stylus', labelKey: 'kind_stylus', color: '#FBBF24' },
  { key: 'printer', labelKey: 'kind_printer', color: '#0F766E' },
  { key: 'router', labelKey: 'kind_router', color: '#2563EB' },
  { key: 'nas', labelKey: 'kind_nas', color: '#A5B4FC' },
  { key: 'powerbank', labelKey: 'kind_powerbank', color: '#FACC15' },
  { key: 'charger', labelKey: 'kind_charger', color: '#F87171' },
  { key: 'fridge', labelKey: 'kind_fridge', color: '#93C5FD' },
  { key: 'washer', labelKey: 'kind_washer', color: '#67E8F9' },
  { key: 'ac', labelKey: 'kind_ac', color: '#2E9BD6' },
  { key: 'microwave', labelKey: 'kind_microwave', color: '#FDBA74' },
  { key: 'fan', labelKey: 'kind_fan', color: '#5EEAD4' },
  { key: 'robot', labelKey: 'kind_robot', color: '#C4B5FD' },
  { key: 'ereader', labelKey: 'kind_ereader', color: '#A8A29E' },
  { key: 'hairdryer', labelKey: 'kind_hairdryer', color: '#FB7185' },
  { key: 'toothbrush', labelKey: 'kind_toothbrush', color: '#4ADE80' },
  { key: 'shaver', labelKey: 'kind_shaver', color: '#60A5FA' },
  { key: 'gamepad', labelKey: 'kind_gamepad', color: '#9333EA' },
  { key: 'other', labelKey: 'kind_other', color: '#9CA3AF' }
];

/**
 * 旧版本分类名 -> 新 key，用于老数据兼容。
 *
 * 注意：下面这些中文是**数据键**，不是界面文案——它们要和已经躺在用户设备里
 * （以及从安卓版导出文件里）的历史 category 字段逐字对上，
 * 所以一个字都不能改、也不能挪进 i18n 表。它们永远不参与展示。
 */
const LEGACY_MAP: string[] = [
  '手机|phone',
  '电脑|laptop',
  '平板|tablet',
  '影音|speaker',
  '家电|other',
  '摄影|camera',
  '其他|other'
];

/** 判断是否为合法的类型 key */
export function isValidKind(key: string): boolean {
  for (let i = 0; i < DEVICE_KINDS.length; i++) {
    if (DEVICE_KINDS[i].key === key) {
      return true;
    }
  }
  return false;
}

/** 把任意脏数据解析成合法 key */
export function resolveKind(key: string): string {
  if (isValidKind(key)) {
    return key;
  }
  for (let i = 0; i < LEGACY_MAP.length; i++) {
    const parts: string[] = LEGACY_MAP[i].split('|');
    if (parts[0] === key) {
      return parts[1];
    }
  }
  return 'other';
}

export function findKind(key: string): DeviceKind {
  const k: string = resolveKind(key);
  for (let i = 0; i < DEVICE_KINDS.length; i++) {
    if (DEVICE_KINDS[i].key === k) {
      return DEVICE_KINDS[i];
    }
  }
  return DEVICE_KINDS[DEVICE_KINDS.length - 1];
}

/**
 * 类型展示名。每次调用都现取，切换语言后所有列表、图例、扇形图立刻跟着变。
 * 键名规则就是 'kind_' + 规范化后的 key，与表里的 labelKey 一一对应。
 */
export function kindLabel(key: string): string {
  return I18n.t('kind_' + resolveKind(key));
}

export function kindColor(key: string): string {
  return findKind(key).color;
}

/** key -> Q 版图标资源 */
export function kindIcon(key: string): Resource {
  switch (resolveKind(key)) {
    case 'phone': return $r('app.media.dev_phone');
    case 'laptop': return $r('app.media.dev_laptop');
    case 'tablet': return $r('app.media.dev_tablet');
    case 'desktop': return $r('app.media.dev_desktop');
    case 'monitor': return $r('app.media.dev_monitor');
    case 'tv': return $r('app.media.dev_tv');
    case 'projector': return $r('app.media.dev_projector');
    case 'camera': return $r('app.media.dev_camera');
    case 'actioncam': return $r('app.media.dev_actioncam');
    case 'drone': return $r('app.media.dev_drone');
    case 'headphone': return $r('app.media.dev_headphone');
    case 'earbuds': return $r('app.media.dev_earbuds');
    case 'speaker': return $r('app.media.dev_speaker');
    case 'smartspeaker': return $r('app.media.dev_smartspeaker');
    case 'mic': return $r('app.media.dev_mic');
    case 'watch': return $r('app.media.dev_watch');
    case 'band': return $r('app.media.dev_band');
    case 'vr': return $r('app.media.dev_vr');
    case 'console': return $r('app.media.dev_console');
    case 'handheld': return $r('app.media.dev_handheld');
    case 'keyboard': return $r('app.media.dev_keyboard');
    case 'mouse': return $r('app.media.dev_mouse');
    case 'drawing': return $r('app.media.dev_drawing');
    case 'stylus': return $r('app.media.dev_stylus');
    case 'printer': return $r('app.media.dev_printer');
    case 'router': return $r('app.media.dev_router');
    case 'nas': return $r('app.media.dev_nas');
    case 'powerbank': return $r('app.media.dev_powerbank');
    case 'charger': return $r('app.media.dev_charger');
    case 'fridge': return $r('app.media.dev_fridge');
    case 'washer': return $r('app.media.dev_washer');
    case 'ac': return $r('app.media.dev_ac');
    case 'microwave': return $r('app.media.dev_microwave');
    case 'fan': return $r('app.media.dev_fan');
    case 'robot': return $r('app.media.dev_robot');
    case 'ereader': return $r('app.media.dev_ereader');
    case 'hairdryer': return $r('app.media.dev_hairdryer');
    case 'toothbrush': return $r('app.media.dev_toothbrush');
    case 'shaver': return $r('app.media.dev_shaver');
    case 'gamepad': return $r('app.media.dev_gamepad');
    default: return $r('app.media.dev_other');
  }
}
