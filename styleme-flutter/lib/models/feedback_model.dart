// StyleMe - Modelo de datos para Feedback
class FeedbackModel {
  static const String liked = 'liked';
  static const String saved = 'saved';
  static const String disliked = 'disliked';
  static const String none = 'none';

  static const List<String> tipos = [liked, saved, disliked];

  static String emoji(String tipo) {
    switch (tipo) {
      case liked:
        return '❤️';
      case saved:
        return '🔖';
      case disliked:
        return '✕';
      default:
        return '';
    }
  }

  static String texto(String tipo) {
    switch (tipo) {
      case liked:
        return 'Me gusta';
      case saved:
        return 'Guardado';
      case disliked:
        return 'No me gusta';
      default:
        return 'Sin feedback';
    }
  }
}
