/// Единые значения оформления: цвета, скругления, отступы, длительности.
///
/// Всё, что раньше вбивалось числами по месту, живёт здесь — чтобы
/// перекрасить или «подышать» интерфейсом можно было в одном файле.
library;

import 'package:flutter/material.dart';

// ── Цвет ────────────────────────────────────────────────────────────────────

/// Фирменная фуксия Handy — тот же акцент, что в десктопной версии.
const Color kAccent = Color(0xFFEC4899);

/// Мягкий розовый для чипов и подсветки выбранной карточки.
const Color kAccentSoft = Color(0xFFF9A8D4);

/// Тёмная фуксия для нажатых состояний и текста на светлом фоне.
const Color kAccentDeep = Color(0xFFBE185D);

/// Запись идёт. Не «пожарный» красный, а роза — рядом с акцентом смотрится
/// тревожно ровно настолько, насколько нужно.
const Color kRecording = Color(0xFFF43F5E);

/// Нужно внимание, но это не ошибка: нет модели, кончается лимит записи.
const Color kWarn = Color(0xFFF59E0B);

/// Успех: модель готова, текст скопирован.
const Color kOk = Color(0xFF10B981);

// Тёмная тема — почти чёрные поверхности с лёгким фиолетовым подтоном,
// как в десктопном Handy.
const Color kDarkSurface = Color(0xFF121014);
const Color kDarkSurfaceLow = Color(0xFF1A171C);
const Color kDarkSurfaceContainer = Color(0xFF201C23);
const Color kDarkSurfaceHigh = Color(0xFF2A252F);
const Color kDarkOutline = Color(0xFF35303A);

// Светлая тема — тёплый белый, чтобы розовый не выглядел кислотным.
const Color kLightSurface = Color(0xFFFDFCFD);
const Color kLightSurfaceLow = Color(0xFFF7F2F5);
const Color kLightSurfaceContainer = Color(0xFFF1EAEE);
const Color kLightOutline = Color(0xFFE2D8DE);

// ── Форма ───────────────────────────────────────────────────────────────────

const double kRadiusCard = 20;
const double kRadiusField = 14;
const double kRadiusSheet = 28;
const double kRadiusPill = 999;

// ── Ритм ────────────────────────────────────────────────────────────────────

const double kGapXS = 4;
const double kGapS = 8;
const double kGapM = 12;
const double kGapL = 16;
const double kGapXL = 24;

/// Боковые поля экрана. Одно значение на всё приложение.
const EdgeInsets kScreenPadding = EdgeInsets.symmetric(horizontal: kGapL);

// ── Движение ────────────────────────────────────────────────────────────────

/// Мелкие отклики: нажатие, смена подписи.
const Duration kFast = Duration(milliseconds: 160);

/// Смена состояния экрана.
const Duration kNormal = Duration(milliseconds: 220);

/// Появление крупных блоков.
const Duration kSlow = Duration(milliseconds: 320);

// ── Типографика ─────────────────────────────────────────────────────────────

/// Семейство рукописного вордмарка (см. `pubspec.yaml`).
const String kScriptFamily = 'HandyScript';

/// Стиль для таймеров и любых «живых» чисел: моноширинные цифры, чтобы
/// строка не дёргалась на каждой смене секунды.
const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];
