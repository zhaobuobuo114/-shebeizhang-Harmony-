/**
 * 设备类型表：key 为存储用标识，label 为展示名，color 为图表/标签主题色。
 * 每个 key 对应一张 Q 版图标（entry/src/main/resources/base/media/dev_<key>.png）。
 */
export interface DeviceKind {
  key: string;
  label: string;
  color: string;
}

export const DEVICE_KINDS: DeviceKind[] = [
  { key: 'phone', label: '手机', color: '#4F8CFF' },
  { key: 'laptop', label: '笔记本', color: '#6C7BFF' },
  { key: 'tablet', label: '平板', color: '#38BDF8' },
  { key: 'desktop', label: '台式主机', color: '#64748B' },
  { key: 'monitor', label: '显示器', color: '#14B8A6' },
  { key: 'tv', label: '电视', color: '#F59E0B' },
  { key: 'projector', label: '投影仪', color: '#8B5CF6' },
  { key: 'camera', label: '相机', color: '#EF4444' },
  { key: 'actioncam', label: '运动相机', color: '#FB923C' },
  { key: 'drone', label: '无人机', color: '#22C55E' },
  { key: 'headphone', label: '头戴耳机', color: '#A855F7' },
  { key: 'earbuds', label: '蓝牙耳机', color: '#EC4899' },
  { key: 'speaker', label: '音箱', color: '#F43F5E' },
  { key: 'smartspeaker', label: '智能音箱', color: '#06B6D4' },
  { key: 'mic', label: '麦克风', color: '#84CC16' },
  { key: 'watch', label: '智能手表', color: '#10B981' },
  { key: 'band', label: '智能手环', color: '#2DD4BF' },
  { key: 'vr', label: 'VR 眼镜', color: '#7C3AED' },
  { key: 'console', label: '游戏主机', color: '#334155' },
  { key: 'handheld', label: '掌上游戏机', color: '#DB2777' },
  { key: 'keyboard', label: '键盘', color: '#475569' },
  { key: 'mouse', label: '鼠标', color: '#94A3B8' },
  { key: 'drawing', label: '数位板', color: '#0891B2' },
  { key: 'stylus', label: '手写笔', color: '#FBBF24' },
  { key: 'printer', label: '打印机', color: '#0F766E' },
  { key: 'router', label: '路由器', color: '#2563EB' },
  { key: 'nas', label: '硬盘 / 存储', color: '#A5B4FC' },
  { key: 'powerbank', label: '充电宝', color: '#FACC15' },
  { key: 'charger', label: '充电器', color: '#F87171' },
  { key: 'fridge', label: '冰箱', color: '#93C5FD' },
  { key: 'washer', label: '洗衣机', color: '#67E8F9' },
  { key: 'ac', label: '空调', color: '#2E9BD6' },
  { key: 'microwave', label: '微波炉', color: '#FDBA74' },
  { key: 'fan', label: '风扇', color: '#5EEAD4' },
  { key: 'robot', label: '扫地机器人', color: '#C4B5FD' },
  { key: 'ereader', label: '电纸书', color: '#A8A29E' },
  { key: 'hairdryer', label: '吹风机', color: '#FB7185' },
  { key: 'toothbrush', label: '电动牙刷', color: '#4ADE80' },
  { key: 'shaver', label: '剃须刀', color: '#60A5FA' },
  { key: 'gamepad', label: '游戏手柄', color: '#9333EA' },
  { key: 'other', label: '其他', color: '#9CA3AF' }
];

/** 旧版本分类名 -> 新 key，用于老数据兼容 */
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

export function kindLabel(key: string): string {
  return findKind(key).label;
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
