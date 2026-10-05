/**
 * 昼夜双主题配色。所有颜色都走这里，切换主题时页面整体重绘。
 */
export interface AppTheme {
  dark: boolean;
  bg: string;          // 页面底色
  bgTop: string;       // 顶部渐变色
  card: string;        // 卡片
  card2: string;       // 次级卡片 / 内嵌块
  text: string;        // 主文字
  text2: string;       // 正文
  sub: string;         // 次要文字
  line: string;        // 分割线
  primary: string;     // 主色
  primary2: string;    // 主色渐变终点
  primarySoft: string; // 主色浅底
  onPrimary: string;   // 主色上的文字
  accent: string;      // 强调色（日均）
  gold: string;        // 收藏星标的金色
  danger: string;
  field: string;       // 输入框底
  chipBg: string;
  chipText: string;
  iconBg: string;      // 图标底板
  shadow: string;
  scrim: string;       // 遮罩
  trackBg: string;     // 进度/空环底色
}

export const LIGHT_THEME: AppTheme = {
  dark: false,
  bg: '#F1F4F9',
  bgTop: '#E7EFFF',
  card: '#FFFFFF',
  card2: '#F5F7FB',
  text: '#171A21',
  text2: '#3E4655',
  sub: '#8B94A3',
  line: '#EDF0F6',
  primary: '#2B5CFF',
  primary2: '#6E8CFF',
  primarySoft: '#E9F0FF',
  onPrimary: '#FFFFFF',
  accent: '#FF7A45',
  gold: '#F5A623',
  danger: '#FF4D4F',
  field: '#F2F4F8',
  chipBg: '#E8ECF3',
  chipText: '#5A6472',
  iconBg: '#EFF3FB',
  shadow: '#141A2B',
  scrim: '#66000000',
  trackBg: '#E8ECF3'
};

export const DARK_THEME: AppTheme = {
  dark: true,
  bg: '#10131A',
  bgTop: '#171D2B',
  card: '#1A1F2A',
  card2: '#232937',
  text: '#F3F6FB',
  text2: '#C7D0DE',
  sub: '#818B9C',
  line: '#252C39',
  primary: '#5B8CFF',
  primary2: '#8AA7FF',
  primarySoft: '#212B45',
  onPrimary: '#0B0E14',
  accent: '#FFA171',
  gold: '#FFC04D',
  danger: '#FF6B6D',
  field: '#242B39',
  chipBg: '#2A3140',
  chipText: '#AEB8C7',
  iconBg: '#232937',
  shadow: '#000000',
  scrim: '#99000000',
  trackBg: '#2A3140'
};

export function themeOf(dark: boolean): AppTheme {
  return dark ? DARK_THEME : LIGHT_THEME;
}
