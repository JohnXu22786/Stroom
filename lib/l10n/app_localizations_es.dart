// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get galleryPermissionTitle =>
      'Se requiere acceso a la biblioteca de fotografías';

  @override
  String get galleryPermissionMessage =>
      'Permita que Stroom acceda a fotos y videos en la configuración del sistema.';

  @override
  String get galleryPermissionCancel => 'Cancelar';

  @override
  String get galleryPermissionOpenSettings => 'Abrir configuración';

  @override
  String get languageSettingsTitle => 'Idioma';

  @override
  String get followSystemLanguage => 'Seguir sistema';

  @override
  String get themeDisplaySettingsTitle => 'Tema y visualización';

  @override
  String get themeDisplayThemeSection => 'Tema';

  @override
  String get themeModeLight => 'Modo claro';

  @override
  String get themeModeDark => 'modo oscuro';

  @override
  String get themeModeSystem => 'Seguir sistema';

  @override
  String get languageNameEnglish => 'Inglés';

  @override
  String get languageNameChinese => 'Chino (simplificado)';

  @override
  String get languageSearchHint => 'Idiomas de búsqueda';

  @override
  String get languageNoMatches => 'No hay idiomas coincidentes';

  @override
  String get builtInPromptGeneralName => 'asistente general';

  @override
  String get builtInPromptGeneralDescription =>
      'Un asistente de IA multiuso para conversaciones cotidianas y respuestas a una amplia gama de preguntas.';

  @override
  String get builtInPromptGeneralPrompt =>
      'Eres un útil asistente de IA. Responder al usuario en el idioma que utiliza. Sea conciso, claro y organizado lógicamente. Si no está seguro de algo, dígalo honestamente.';

  @override
  String get builtInPromptCodeExpertName => 'Experto en código';

  @override
  String get builtInPromptCodeExpertDescription =>
      'Un programador experimentado con experiencia en muchos lenguajes de programación y pilas de tecnología.';

  @override
  String get builtInPromptCodeExpertPrompt =>
      'Usted es un ingeniero de software experimentado y experto en muchos lenguajes de programación y pilas de tecnología. Según la pregunta del usuario, proporcione ejemplos de código de alta calidad, explicaciones técnicas y recomendaciones de mejores prácticas. Priorice la legibilidad, el rendimiento y la seguridad. Al proporcionar el código, etiquete el idioma y utilice el formato adecuado. Para preguntas sobre diseño de sistemas, analice las compensaciones desde una perspectiva de arquitectura.';

  @override
  String get builtInPromptTranslationName => 'Asistente de traducción';

  @override
  String get builtInPromptTranslationDescription =>
      'Un traductor profesional para traducción multilingüe y asesoramiento en localización.';

  @override
  String get builtInPromptTranslationPrompt =>
      'Eres un traductor profesional. Tus responsabilidades son:\n1. Traducir con precisión el contenido que proporciona el usuario conservando su estilo y tono.\n2. Dar una expresión natural cuando el usuario pregunte cómo decir algo en un idioma en particular.\n3. Ofrecer asesoramiento sobre localización de contenidos culturalmente específicos.\n4. Cuando sean posibles varias traducciones, enumerelas y explique sus diferencias.\nIdentifique siempre primero los idiomas de origen y de destino; Pregúntele al usuario si alguno de los dos no está claro.';

  @override
  String get builtInPromptEnglishTeacherName => 'profesora de ingles';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      'Un tutor de aprendizaje de inglés que ayuda a mejorar la escucha, el habla, la lectura y la escritura.';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      'Eres un profesor de inglés con experiencia. Satisfacer las necesidades del usuario con:\n1. Explicaciones gramaticales: explique las reglas con claridad e incluya ejemplos.\n2. Aprendizaje de vocabulario: explicar el uso, las colocaciones y las distinciones de las palabras.\n3. Escritura pulida: mejora el inglés para que suene natural.\n4. Práctica de conversación: simular situaciones de habla inglesa.\n5. Guía de pronunciación: utilice símbolos fonéticos y pronunciación aproximada.\nAjuste la dificultad al nivel de inglés del usuario y utilice el español para facilitar las explicaciones.';

  @override
  String get builtInPromptInterviewerName => 'Entrevistador';

  @override
  String get builtInPromptInterviewerDescription =>
      'Un entrevistador simulado para entrevistas técnicas y conductuales.';

  @override
  String get builtInPromptInterviewerPrompt =>
      'Eres un entrevistador profesional. Realice una entrevista de práctica para el rol objetivo del usuario:\n1. Primero, conozca la posición y la industria de destino.\n2. Haga preguntas técnicas, de comportamiento y de diseño de sistemas relevantes.\n3. Evaluar las respuestas del usuario y sugerir mejoras.\n4. Proporcione ejemplos de respuestas y razonamientos.\n5. Mantenga un ritmo realista: haga una o dos preguntas y luego espere al usuario.\nSea profesional y amigable, con el objetivo de ayudar al usuario a mejorar sus habilidades para la entrevista.';

  @override
  String get builtInPromptWritingName => 'Asistente de redacción';

  @override
  String get builtInPromptWritingDescription =>
      'Un asistente de redacción y edición para muchos géneros y escritura creativa.';

  @override
  String get builtInPromptWritingPrompt =>
      'Eres un consultor de redacción profesional. Según las necesidades del usuario, proporcione:\n1. Redacción: escribir en géneros como argumentativo, expositivo y narrativo.\n2. Edición: mejorar la gramática, la elección de palabras, la lógica, la estructura y la expresión.\n3. Delinear: ayudar a construir un marco e identificar puntos clave.\n4. Ideas creativas: ofrece inspiración y ángulos posibles.\n5. Formato: siga las convenciones del género de destino y los requisitos de envío.\nPrimero, comprenda el propósito, los lectores previstos y el estilo deseado, luego brinde consejos específicos.';

  @override
  String get builtInPromptCreativeThinkerName => 'Pensador creativo';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      'Un socio de ideas creativas y lluvia de ideas que genera nuevas ideas.';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      'Eres un compañero de pensamiento creativo. Tus tareas son:\n1. Lluvia de ideas: ofrezca direcciones creativas variadas en torno a un tema.\n2. Desarrollar conceptos: profundizar y ampliar las ideas existentes.\n3. Conectar campos: combinar conceptos de diferentes áreas de nuevas formas.\n4. Pensar al revés: desafiar el pensamiento convencional y ofrecer perspectivas inusuales.\n5. Revisión de viabilidad: analizar los desafíos de implementación y el valor potencial.\nFomente el pensamiento divergente mientras enfoca la discusión en el momento adecuado. Ofrezca de tres a cinco instrucciones por respuesta.';

  @override
  String get builtInPromptDataAnalystName => 'Analista de datos';

  @override
  String get builtInPromptDataAnalystDescription =>
      'Un experto en análisis de datos que ayuda a comprender, modelar y visualizar datos.';

  @override
  String get builtInPromptDataAnalystPrompt =>
      'Eres un experto en análisis de datos. Según la pregunta del usuario, proporcione:\n1. Métodos de análisis: elegir métodos estadísticos y marcos analíticos adecuados.\n2. Código SQL/Python/R: proporcione ejemplos de procesamiento y análisis de datos.\n3. Consejos de visualización: recomiende tipos de gráficos y herramientas adecuados.\n4. Interpretación: explicar los hallazgos y su significado comercial.\n5. Limpieza de datos: maneje valores faltantes, valores atípicos y otros problemas de calidad.\nPrimero, aclare el objetivo del análisis y las características de los datos. Prefiere el ecosistema Python (pandas, numpy, matplotlib, seaborn).';

  @override
  String get builtInPromptRoleplayName => 'Juego de roles';

  @override
  String get builtInPromptRoleplayDescription =>
      'Una experiencia de juego de rol inmersiva con múltiples personajes.';

  @override
  String get builtInPromptRoleplayPrompt =>
      'Ya estás en modo de interpretación. Interpreta al personaje indicado por el usuario y responde de acuerdo con su personalidad, tono y conocimientos:\n1. Cuando el usuario diga «interpreta a [personaje]», cambia de inmediato a ese personaje.\n2. Mantén el papel durante toda la conversación.\n3. Adapta el estilo y los conocimientos del personaje a su descripción.\n4. El usuario puede decir «terminar el juego de rol» para detenerlo.\n5. Puedes añadir detalles ficticios razonables que encajen con el personaje.\nEspera a que el usuario indique qué personaje quiere que interpretes.';

  @override
  String get builtInPromptLifeAdvisorName => 'Asesor de vida';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      'Un oyente cálido y atento que ofrece apoyo para la salud mental y consejos cotidianos.';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      'Eres un asesor de vida cálido y reflexivo. Tus responsabilidades son:\n1. Escuchar activamente y comprender las inquietudes y necesidades emocionales del usuario.\n2. Analizar los problemas de forma racional y ayudar al usuario a analizar sus aspectos.\n3. Ofrecer formas concretas y viables de mejorar la vida cotidiana.\n4. Brinde comprensión, aliento y apoyo positivo.\n5. Sugerir ayuda profesional cuando sea necesario.\nRecuerde: usted no es un consejero de salud mental autorizado. En caso de una crisis grave de salud mental, anime al usuario a buscar ayuda profesional. Sea empático sin excederse; apoyar al usuario sin tomar decisiones por él.';

  @override
  String get builtInSystemTitleName => 'Asistente de título';

  @override
  String get builtInSystemTitleDescription =>
      'Genera un título corto automáticamente a partir de la conversación.';

  @override
  String get builtInSystemTitlePrompt =>
      'Eres un generador de títulos. Muestra un título de conversación y nada más.\n\nReglas:\n- Utilice una línea y no más de 50 caracteres.\n- No explicar ni utilizar comillas.\n- Utilizar el mismo idioma que los mensajes del usuario.\n- No incluya nombres de herramientas como web_search o todowrite en el título.\n\nEjemplos:\n“Ayúdame a depurar un error de producción 500” → Depurar un error de producción 500\n“Refactorizar el servicio de usuario” → Refactorizar el servicio de usuario\n\"¿Por qué falla app.js?\" → Solución de problemas de app.js\n\nSi el mensaje del usuario es muy breve o simplemente un saludo (como “hola”, “jaja” o “¿estás ahí?”), crea un título que refleje su tono o intención, como un saludo, una charla informal o una confirmación rápida.';

  @override
  String get builtInSystemCompactionName =>
      'Asistente de compactación de contexto';

  @override
  String get builtInSystemCompactionDescription =>
      'Condensa una larga conversación en un resumen estructurado y anclado para liberar espacio de contexto.';

  @override
  String get builtInSystemCompactionPrompt =>
      'Eres un asistente de resúmenes de contexto anclado. Condense largas conversaciones en resúmenes estructurados.\n\nResuma solo el historial de conversaciones proporcionado. Los mensajes recientes pueden conservarse palabra por palabra, así que concéntrese en el contexto más antiguo que aún sea importante.\n\nSi el mensaje contiene un bloque <previous-summary>, trátelo como el resumen anclado actual: mantenga lo que aún es cierto, elimine el material obsoleto e integre nuevos hechos.\n\nSiga esta estructura exactamente. Mantenga el orden de las secciones e incluya todas las secciones, incluso si están vacías:\n<plantilla>\n## Objetivo\n- [El objetivo del usuario en una o dos frases]\n\n## Detalles importantes\n- [Limitaciones/preferencias, decisiones y razones, hechos/suposiciones importantes y contexto preciso necesario para continuar; escriba (ninguno) si está vacío]\n\n## Estado de trabajo\n### Completado\n- [Trabajo completado, hechos verificados o cambios realizados; escriba (ninguno) si está vacío]\n\n### Activo\n- [Trabajo actual, cambios parciales o investigación; escriba (ninguno) si está vacío]\n\n### Bloqueado\n- [Bloqueadores, comandos fallidos o desconocidos; escriba (ninguno) si está vacío]\n\n## Siguiente movimiento\n1. [La siguiente acción específica, o (ninguna)]\n2. [Acción de seguimiento conocida, o (ninguna)]\n\n## Archivos relevantes\n- [Ruta del archivo o directorio y por qué es importante; escriba (ninguno) si está vacío]\n</plantilla>\n\nReglas:\n- Incluir todas las secciones, incluso si están vacías.\n- Utilice viñetas concisas, no párrafos.\n- Conserve rutas exactas de archivos, símbolos, comandos, mensajes de error, URL e identificadores.\n- No menciones que estás resumiendo, compactando o fusionando contexto.\n- Utilizar el mismo lenguaje de la conversación.';

  @override
  String get builtInPromptMarketTitle => 'Asistente de Mercado';

  @override
  String get builtInPromptClose => 'Cerrar';

  @override
  String get builtInPromptImportHint =>
      'Las indicaciones importadas se convierten en asistentes habituales que puedes editar libremente.';

  @override
  String get builtInPromptView => 'Ver aviso';

  @override
  String get builtInPromptAdd => 'Agregar';

  @override
  String get builtInPromptDescriptionHeading => 'Descripción';

  @override
  String get builtInPromptSystemPromptHeading => 'Aviso del sistema';

  @override
  String get builtInPromptAddAssistant => 'Agregar asistente';

  @override
  String builtInPromptViewerTitle(Object name) {
    return 'Aviso · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      'Configure un modelo separado y solicite la generación automática de títulos y la compactación del contexto. De forma predeterminada, se utilizan el modelo de chat actual y las indicaciones integradas.';

  @override
  String get systemAssistantTitleName => 'Asistente de generación de títulos';

  @override
  String get systemAssistantTitleDescription =>
      'Genera automáticamente títulos de conversaciones';

  @override
  String get systemAssistantCompactionName =>
      'Asistente de compactación de contexto';

  @override
  String get systemAssistantCompactionDescription =>
      'Condensa largas conversaciones en resúmenes anclados';

  @override
  String get systemAssistantFollowCurrentModel =>
      'Sigue el modelo de chat actual';

  @override
  String get systemAssistantChooseModel => 'Elige un modelo';

  @override
  String get systemAssistantResetPromptTitle =>
      'Restablecer el mensaje predeterminado';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '¿Restaurar el mensaje predeterminado incorporado para “$taskTitle”? Su mensaje personalizado actual será descartado.';
  }

  @override
  String get systemAssistantCancel => 'Cancelar';

  @override
  String get systemAssistantReset => 'Reiniciar';

  @override
  String get systemAssistantModelHeading => 'Modelo';

  @override
  String get systemAssistantPromptHeading => 'Instrucción';

  @override
  String get systemAssistantCustomPromptHint =>
      'Los cambios se utilizarán como un mensaje personalizado.';

  @override
  String get systemAssistantUsingCustomPrompt =>
      'Usando un mensaje personalizado';

  @override
  String get systemAssistantUsingDefaultPrompt =>
      'Usando el mensaje predeterminado';

  @override
  String get systemAssistantSave => 'Guardar';

  @override
  String get systemAssistantResetButton =>
      'Restablecer el mensaje predeterminado';

  @override
  String get taskFlowPageTitle => 'Flujos de tareas';

  @override
  String get taskFlowSampleTemplatesTooltip => 'Plantillas de ejemplo';

  @override
  String get taskFlowEmptyState => 'Aún no hay flujos. Toca + para crear uno.';

  @override
  String get taskFlowStartFromTemplate => 'Empezar desde una plantilla';

  @override
  String get taskFlowChooseTemplate => 'Elija una plantilla de ejemplo';

  @override
  String get taskFlowTemplateIntroduction =>
      'Elija un flujo cercano a lo que necesita; Puedes ajustarlo más tarde.';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plantillas',
      one: '$count plantilla',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      'Las plantillas se abren como borradores que necesitan configuración. Elija un modelo y asistente antes de guardar.';

  @override
  String get taskFlowTemplateRecordingName =>
      'Transcribir y resumir una grabación';

  @override
  String get taskFlowTemplateRecordingDescription =>
      'Elija una grabación → reconocimiento de voz → resumen del asistente';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'Configura un modelo ASR y elige un asistente para el resumen.';

  @override
  String get taskFlowTemplateImageTextName =>
      'Reconocer y organizar texto de imagen';

  @override
  String get taskFlowTemplateImageTextDescription =>
      'Elija una imagen → reconocimiento de texto → organización asistente';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'Configura un modelo OCR y elige un asistente para organizar el texto.';

  @override
  String get taskFlowTemplateReadImageName => 'Leer texto de una imagen';

  @override
  String get taskFlowTemplateReadImageDescription =>
      'Elija una imagen → reconocimiento de texto → reproducción de voz';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'Configure los modelos de síntesis de voz y OCR y luego elija una voz.';

  @override
  String get taskFlowActions => 'Acciones de flujo';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloques',
      one: '$count bloque',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'LOC';

  @override
  String get taskFlowBlockAsr => 'Reconocimiento de voz';

  @override
  String get taskFlowBlockAudioSeparation => 'Separación de audio';

  @override
  String get taskFlowBlockCatCatch => 'Descarga de recursos web';

  @override
  String get taskFlowBlockTts => 'Síntesis del habla';

  @override
  String get taskFlowBlockChat => 'Asistente de chat';

  @override
  String get taskFlowBlockCustom => 'Bloque personalizado';

  @override
  String get taskFlowEdit => 'Editar';

  @override
  String get taskFlowCopy => 'Copiar';

  @override
  String get taskFlowCopied => 'Copiado';

  @override
  String get taskFlowDelete => 'Borrar';

  @override
  String get taskFlowConfirmDelete => 'Confirmar eliminación';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return '¿Eliminar el flujo de tareas “$flowName”?';
  }

  @override
  String get taskFlowUseTemplate => 'Usar';

  @override
  String get taskFlowOcrInputMissing =>
      'No se pudo encontrar el archivo de imagen. Seleccione la imagen nuevamente.';

  @override
  String get taskFlowOcrInputReadFailed =>
      'No se pudo leer el archivo de imagen. Verifique el acceso al archivo e inténtelo nuevamente.';

  @override
  String get taskFlowOcrModelUnavailable =>
      'No se ha configurado ningún modelo de OCR utilizable. Elija un proveedor y modelo de OCR en la configuración de flujo.';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'Presupuesto de tamaño de solicitud de OCR ($size MiB)';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return 'el límite de entrada de imagen de flujo de tareas ($size MiB)';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return 'La imagen supera $limit. Elija una imagen más pequeña e inténtelo de nuevo.';
  }

  @override
  String get ocrTemplatePlainTextLabel => 'Texto sin formato';

  @override
  String get ocrTemplatePlainTextContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página, conservando los saltos de línea y los párrafos. Devuelve sólo texto sin formato; no agregue explicaciones o inferencias.';

  @override
  String get ocrTemplateMarkdownLabel => 'Reducción';

  @override
  String get ocrTemplateMarkdownContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página y utiliza Markdown para conservar títulos, listas y tablas. Representar fórmulas matemáticas en LaTeX. Devuelve sólo la transcripción; no agregue explicaciones o inferencias.';

  @override
  String get ocrTemplateTableLabel => 'Mesas';

  @override
  String get ocrTemplateTableContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página. Para las tablas, conserve los encabezados, las relaciones de filas y columnas, y las celdas vacías, y generelos como tablas Markdown. Mantenga el resto del contenido como texto normal. Devuelve sólo la transcripción; no agregue explicaciones o inferencias.';

  @override
  String get ocrTemplateLatexLabel => 'Látex';

  @override
  String get ocrTemplateLatexContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página. Preservar texto sin fórmulas y representar fórmulas matemáticas en LaTeX; use \$...\$ para fórmulas en línea y \$\$...\$\$ para fórmulas de visualización. Devuelve sólo la transcripción; no agregue explicaciones o inferencias.';

  @override
  String get ocrDefaultImagesOnly => 'Predeterminado (enviar solo imágenes)';

  @override
  String get ocrDefaultSystemPrompt =>
      'Extraiga todo el texto de la imagen, conservando su formato y diseño originales. Devuelve sólo el texto extraído; No agregues ninguna explicación.';

  @override
  String get ocrSavedInstructionSnapshot =>
      'Instantánea de instrucciones guardadas';

  @override
  String get ocrPageTitle => 'Reconocimiento de texto de imagen';

  @override
  String get ocrImageQualitySettings => 'Configuración de calidad de imagen';

  @override
  String get ocrImageQualityStandard => 'Calidad estándar';

  @override
  String get ocrImageQualityStandardHint =>
      'Imágenes más pequeñas para la mayoría de los casos de uso';

  @override
  String get ocrImageQualityOriginal => 'Original/alto detalle';

  @override
  String get ocrImageQualityOriginalHint =>
      'Mantiene más detalles; Las imágenes y las solicitudes son más grandes.';

  @override
  String get ocrReorderDone => 'Hecho';

  @override
  String get ocrReorderAction => 'Reordenar';

  @override
  String get ocrClearAction => 'Limpiar';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return 'La tarea anterior utilizó el modelo $modelId. Elija nuevamente un proveedor y modelo.';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      'La posición del modelo en el registro de reintento anterior no es válida. Elige un modelo nuevamente.';

  @override
  String get ocrLegacyModelPositionConfirm =>
      'El registro de reintento anterior guardó solo la posición del modelo. Confirme el modelo actual antes de continuar.';

  @override
  String get ocrModelUnavailable =>
      'El proveedor o modelo de OCR original ya no está disponible. Elige otro.';

  @override
  String get ocrModelLabel => 'Modelo';

  @override
  String get ocrConfigure => 'Configurar';

  @override
  String get ocrSelectModel => 'Selecciona un modelo';

  @override
  String get ocrInstructionLabel => 'Instrucción';

  @override
  String get ocrManageInstructions =>
      'Gestionar instrucciones de reconocimiento';

  @override
  String get ocrInstructionManageGuidance =>
      'Estas instrucciones se aplican a todos los modelos de reconocimiento. Si no se selecciona ninguno, solo se envía la imagen.';

  @override
  String get ocrInstructionManageEmpty => 'Aún no hay instrucciones';

  @override
  String get ocrInstructionEditTooltip => 'Editar instrucción';

  @override
  String get ocrInstructionDeleteTooltip => 'Eliminar instrucción';

  @override
  String get ocrInstructionAdd => 'Agregar instrucción';

  @override
  String get ocrInstructionEditorEditTitle => 'Editar instrucción';

  @override
  String get ocrInstructionNameLabel => 'Nombre de la instrucción (opcional)';

  @override
  String get ocrInstructionContentLabel => 'Contenido de la instrucción';

  @override
  String get ocrBatchMode => 'Modo por lotes';

  @override
  String get ocrMergeRecognition => 'Combinar resultados';

  @override
  String get ocrRecognizeEachImage => 'Reconocer cada imagen por separado';

  @override
  String get ocrMaxConcurrency => 'Hasta 2 solicitudes simultáneas';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes simultáneas',
      one: '$count solicitud simultánea',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes simultáneas',
      one: '$count solicitud simultánea',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint =>
      'Las páginas completadas se conservan; reintentar envía sólo páginas sin terminar.';

  @override
  String get ocrTakePhoto => 'tomar una foto';

  @override
  String get ocrChooseFromAlbum => 'Elige del álbum';

  @override
  String get ocrNoImagesSelected => 'No hay imágenes seleccionadas';

  @override
  String get ocrSelectImagesHint =>
      'Tome una foto o seleccione varias imágenes de su álbum para reconocerlas.';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'las imágenes requeridas',
      one: 'la imagen requerida',
    );
    return 'Vuelve a seleccionar $_temp0 antes de reintentar.';
  }

  @override
  String ocrImageLabel(Object index) {
    return 'Imagen $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return 'Imagen_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => 'Índice de imagen no válido';

  @override
  String get ocrViewErrorDetails => 'Ver detalles del error';

  @override
  String get ocrConfirmModel => 'Confirmar este modelo';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imágenes seleccionadas',
      one: '$count imagen seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => 'Preparando imágenes…';

  @override
  String get ocrSavingRetryImages => 'Guardando imágenes de reintento…';

  @override
  String get ocrRecognizing => 'Reconociendo…';

  @override
  String get ocrReadingRetryImages => 'Leyendo imágenes de reintento…';

  @override
  String get ocrImportingImages => 'Importando imágenes…';

  @override
  String get ocrStartRecognition => 'Iniciar reconocimiento';

  @override
  String get ocrSaveTo => 'Guardar en';

  @override
  String get ocrRootDirectory => 'directorio raíz';

  @override
  String get ocrChooseSaveFolder => 'Elija una carpeta para guardar';

  @override
  String get ocrChooseImageSource => 'Elige la fuente de la imagen';

  @override
  String get ocrChooseAppAlbum => 'Elija del álbum de aplicaciones';

  @override
  String get ocrAppAlbumDescription =>
      'Elija imágenes ya guardadas en la aplicación';

  @override
  String get ocrChooseSystemAlbum => 'Elija del álbum del sistema';

  @override
  String get ocrSystemAlbumDescription =>
      'Explora y elige imágenes en este dispositivo';

  @override
  String ocrTakePhotoFailed(Object error) {
    return 'Error al tomar la foto: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return 'Error al seleccionar la imagen: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se cargaron $count imágenes',
      one: 'Se cargó $count imagen',
    );
    return '$_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return 'Error al procesar la imagen: $error';
  }

  @override
  String get ocrUnknownSourceImageCount =>
      'No se puede determinar el recuento de imágenes originales';

  @override
  String get ocrConfirmClear => 'Confirmar claro';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      'La caché de imágenes OCR original no está disponible y su recuento de imágenes no se puede recuperar. Al borrarlo se restablecerá el estado de reintento anterior. Seleccione todas las imágenes para esta tarea de OCR nuevamente.';

  @override
  String get ocrConfirmClearSelected =>
      '¿Borrar las imágenes OCR seleccionadas?';

  @override
  String get ocrCancel => 'Cancelar';

  @override
  String get ocrConfirmResetAndReselect =>
      'Restablecer y seleccionar imágenes nuevamente';

  @override
  String get ocrRequestCheckFailed =>
      'No se puede verificar la solicitud de OCR. Verifique los parámetros del modelo.';

  @override
  String get ocrCancelledAdjustAndRetry =>
      'Se canceló el reconocimiento. Ajuste el tamaño de la solicitud de proveedor/modelo o la calidad de la imagen y vuelva a intentarlo.';

  @override
  String get ocrRequestSizeExceededTitle =>
      'La solicitud de OCR excede el tamaño configurado';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return 'La solicitud es sobre $requestSize MiB, que excede el límite de MiB $limit configurado.';
  }

  @override
  String get ocrRequestSizeHelp =>
      'Ajuste el tamaño de la solicitud en los valores predeterminados del proveedor o en las anulaciones de modelos, o elija una calidad de imagen diferente. Después de cambiar la calidad, borre e importe las imágenes nuevamente.';

  @override
  String get ocrUsePerImageMode => 'Utilice el reconocimiento por imagen';

  @override
  String get ocrGotIt => 'Entiendo';

  @override
  String get ocrWaitForImport =>
      'Espere a que finalice la importación de la imagen antes de comenzar el reconocimiento.';

  @override
  String get ocrWaitForRetryImages =>
      'Lectura de imágenes de reintento. Espere por favor.';

  @override
  String get ocrConfigureProviderModel =>
      'Configure primero un proveedor y un modelo de OCR en Configuración.';

  @override
  String get ocrReselectProviderModel =>
      'Seleccione nuevamente un proveedor y modelo de OCR.';

  @override
  String get ocrConfirmLegacyModel =>
      'Primero confirme el modelo de OCR del registro de reintento anterior.';

  @override
  String get ocrRetryImagesUnavailable =>
      'La caché de imágenes OCR original no está disponible. Borre la tarea y seleccione todas las imágenes nuevamente.';

  @override
  String get ocrRetryImageCountUnknown =>
      'La caché de imágenes OCR original no está disponible y se desconoce su recuento de imágenes. Restablezca y seleccione todas las imágenes para esta tarea de OCR nuevamente.';

  @override
  String get ocrRetryImageReset =>
      'Se restableció la entrada de reintento anterior. Seleccione todas las imágenes para esta tarea de OCR nuevamente.';

  @override
  String get ocrRetryImagesUnreadable =>
      'No se pudo leer el caché de imagen OCR original. Borre la tarea y seleccione todas las imágenes nuevamente.';

  @override
  String get ocrRetryImagesMissing =>
      'La memoria caché de la imagen OCR original falta o está dañada. Borre la tarea y seleccione todas las imágenes nuevamente.';

  @override
  String get ocrImageListChanged =>
      'La lista de imágenes cambió. Inicie el reconocimiento nuevamente.';

  @override
  String get ocrReadInstructionFailed =>
      'No se pueden leer las instrucciones de reconocimiento. Intentar otra vez.';

  @override
  String get ocrErrorDetails => 'Detalles del error';

  @override
  String get ocrRequestHeading => 'Pedido';

  @override
  String get ocrResponseHeading => 'Respuesta';

  @override
  String get ocrNoDetails => 'No hay detalles disponibles';

  @override
  String get ocrImageLoadFailed => 'No se puede cargar la imagen';

  @override
  String get ocrCrop => 'Cultivo';

  @override
  String get ocrEdit => 'Editar';

  @override
  String get ocrProcessingOcrFailed =>
      'No se pudieron procesar las imágenes OCR. Por favor inténtalo de nuevo.';

  @override
  String get settingsPageTitle => 'Ajustes';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionProviders => 'Proveedores';

  @override
  String get settingsSectionSystemAssistant => 'Asistentes del sistema';

  @override
  String get settingsSectionContextManagement => 'Gestión del contexto';

  @override
  String get settingsSectionManagement => 'Gestión';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsBackupRestore => 'Copia de seguridad y restauración';

  @override
  String get settingsBackupRestoreDescription =>
      'Exportar o importar datos de aplicaciones';

  @override
  String get settingsCookies => 'Cookies y datos del navegador';

  @override
  String get settingsCookiesDescription =>
      'Administrar cookies persistentes y almacenamiento del navegador';

  @override
  String get settingsAppLogs => 'Registros de aplicaciones';

  @override
  String get settingsAppLogsDescription =>
      'Ver registros de tiempo de ejecución de la aplicación';

  @override
  String get settingsThemeDisplay => 'Tema y visualización';

  @override
  String get settingsThemeDisplayDescription =>
      'Modo oscuro e idioma de visualización';

  @override
  String get settingsTaskNotifications =>
      'Notificaciones de finalización de tareas';

  @override
  String get settingsTaskNotificationsDescription =>
      'Verifique el permiso de notificación y la configuración del sistema, y ​​vea la guía de notificación';

  @override
  String get settingsBackgroundOptimization =>
      'Optimización de la operación en segundo plano';

  @override
  String get settingsBackgroundOptimizationDescription =>
      'Verifique el entorno del sistema y el estado del servicio en segundo plano, y vea la guía de optimización';

  @override
  String get aboutVersionInfo => 'Ver información de la versión';

  @override
  String get aboutCheckUpdates => 'Buscar actualizaciones';

  @override
  String aboutNewVersionFound(Object version) {
    return 'Nueva versión $version disponible';
  }

  @override
  String get aboutNewVersion => 'Nueva versión';

  @override
  String get aboutPreviewUpdates => 'Vista previa de actualizaciones';

  @override
  String get aboutPreviewUpdatesDescription =>
      'Habilitar comprobaciones para versiones preliminares';

  @override
  String get aboutProjectHome => 'Inicio del proyecto';

  @override
  String get aboutFeedback => 'Informar un problema';

  @override
  String get aboutPrivacyPolicy => 'política de privacidad';

  @override
  String get aboutOpenSourceAgreement => 'Acuerdo de código abierto';

  @override
  String get aboutOpenSourceLicenses => 'Licencias de código abierto';

  @override
  String get aboutCheckingUpdates => 'Buscando actualizaciones...';

  @override
  String get aboutUpToDate => 'Estás usando la última versión.';

  @override
  String aboutUpdateNetworkError(Object details) {
    return 'Error de red: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return 'La verificación de actualización falló con el estado HTTP $statusCode.';
  }

  @override
  String get aboutUpdateInvalidResponse =>
      'El servidor de actualización arrojó una respuesta inesperada.';

  @override
  String get aboutUpdateCheckFailed =>
      'La verificación de actualización falló. Por favor inténtalo de nuevo.';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return 'Error en la comprobación de actualización del asistente: $error';
  }

  @override
  String get aboutPrivacyContent =>
      'Stroom respeta y protege la privacidad de todos los que utilizan el servicio.\n\n1. Permiso de cámara: Se utiliza únicamente para tomar fotografías. No se recopilan ni cargan datos de imágenes.\n\n2. Permiso de la biblioteca de fotografías: Se utiliza únicamente para elegir y guardar fotografías. Todas las fotos se almacenan localmente en su dispositivo.\n\n3. Seguridad de los datos: todas las fotos que toma se almacenan localmente en su dispositivo. No accedemos ni subimos sus datos.\n\n4. Servicios de terceros: esta aplicación no contiene servicios de publicidad ni análisis de terceros.\n\nContáctenos si tiene preguntas.';

  @override
  String get aboutClose => 'Cerrar';

  @override
  String get contextToolPruneTitle =>
      'Podar automáticamente los resultados de la herramienta (Prune)';

  @override
  String get contextToolPruneDescription =>
      'Reemplace automáticamente los resultados de herramientas antiguas que superen el umbral con marcadores de posición para liberar almacenamiento y contexto.';

  @override
  String get contextCompactionTriggerSettings =>
      'Configuración del activador de compactación';

  @override
  String get contextCompactionDisabled =>
      'Deshabilitado (la compactación no se ejecutará)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return 'Activador global $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anulaciones específicas del modelo',
      one: '$count anulación específica del modelo',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle =>
      'Configuración del activador de compactación';

  @override
  String get contextAutoCompaction => 'Compactación automática de contexto';

  @override
  String get contextAutoCompactionDisabled =>
      'Cuando está deshabilitado, la compactación no se ejecutará para ningún modelo.';

  @override
  String get contextGlobalTrigger => 'Porcentaje de activación global';

  @override
  String get contextGlobalTriggerDescription =>
      'Los modelos sin una configuración individual utilizan este porcentaje de la ventana de contexto del modelo como activador de compactación.';

  @override
  String contextResetPercent(Object percent) {
    return 'Restablecer a $percent%';
  }

  @override
  String get contextPerModelSettings => 'Configuración por modelo';

  @override
  String get contextNoConfiguredModels => 'No hay modelos configurados';

  @override
  String contextIndependentThreshold(Object threshold) {
    return 'Umbral independiente: tokens $threshold';
  }

  @override
  String get contextEnterIndependentThreshold =>
      'Introduzca un umbral independiente a continuación';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return 'Seguir global $percent%';
  }

  @override
  String get contextThresholdField => 'Umbral independiente (tokens)';

  @override
  String get contextThresholdHint =>
      'Por ejemplo, 48000 (recuento de tokens, no porcentaje)';

  @override
  String get contextPercentField => 'Porcentaje';

  @override
  String contextPercentHint(Object percent) {
    return 'Por ejemplo, $percent';
  }

  @override
  String get versionInfoTitle => 'Información de versión';

  @override
  String get versionNumberLabel => 'Versión';

  @override
  String get versionReleaseTimeLabel => 'tiempo de liberación';

  @override
  String get versionLocalBuild => 'Construcción local';

  @override
  String get versionReleaseNotesLabel => 'Notas de la versión';

  @override
  String get versionClose => 'Cerrar';

  @override
  String get updateDialogTitle => 'Nueva versión disponible';

  @override
  String get updateLatestVersionLabel => 'Última versión';

  @override
  String get updateSelectedVersionLabel => 'Versión seleccionada';

  @override
  String get updateReleaseNotesLabel => 'Notas de la versión';

  @override
  String get updateInstalling => 'Instalando…';

  @override
  String get updateDownloadComplete => 'Descarga completa';

  @override
  String get updateClose => 'Cerrar';

  @override
  String get updateManualInstall => 'Instalar manualmente';

  @override
  String get updateOpenInstaller => 'Abrir instalador';

  @override
  String get updateRetryDownload => 'Reintentar descargar';

  @override
  String get updateSkipVersion => 'Saltar esta versión';

  @override
  String get updateRemindLater => 'Recuérdamelo más tarde';

  @override
  String get updateOpenBrowser => 'Descargar en el navegador';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updatePreviewBadge => 'Avance';

  @override
  String get updateLatestBadge => 'El último';

  @override
  String get updateSelectVersion => 'Seleccionar versión';

  @override
  String get updateDownloading => 'Descargando actualización…';

  @override
  String updateCheckNetworkError(Object details) {
    return 'Error de red: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return 'No se pudieron buscar actualizaciones: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      'No se pudieron buscar actualizaciones: el servidor devolvió datos no reconocidos';

  @override
  String get updateDownloadUrlUnavailable =>
      'La URL de descarga no está disponible.';

  @override
  String get updateNoDirectDownloadLink =>
      'No existe un enlace de descarga directa para esta plataforma. Descárgalo en un navegador.';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return 'La instalación automática falló: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return 'Error de descarga: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return 'Descarga fallida: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return 'Error de instalación: $details';
  }

  @override
  String updateFailed(Object details) {
    return 'Error en la actualización: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return 'No se pudo abrir el archivo. Instálelo manualmente: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return 'La instalación falló. Abra el APK manualmente: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails =>
      'La instalación falló. Abra el APK manualmente.';

  @override
  String get updateApkInstallerUnavailable =>
      'No se pudo encontrar una aplicación para instalar este APK. Ábrelo manualmente.';

  @override
  String get updateApkInstallPermissionDenied =>
      'Permita que Stroom instale aplicaciones desconocidas en la configuración del sistema.';

  @override
  String get updateRestartDialogTitle => 'Aplicación actualizada';

  @override
  String get updateRestartDialogBody =>
      'La aplicación ha sido actualizada. Reinicie la aplicación para garantizar la estabilidad.';

  @override
  String get updateRestartDialogLater => 'Reiniciar más tarde';

  @override
  String get updateRestartDialogNow => 'Reiniciar ahora';

  @override
  String get contextCompactionHistoryIntro =>
      'Historial de conversaciones para condensar:';

  @override
  String get contextCompactionUserRole => 'Usuario';

  @override
  String get contextCompactionAssistantRole => 'Asistente';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role herramienta llamada $toolName: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      'Condense el historial de conversaciones anterior en un resumen anclado, siguiendo exactamente la plantilla.';

  @override
  String get ocrImageEmpty => 'La imagen está vacía. Selecciónelo nuevamente.';

  @override
  String get ocrImageUnsupportedFormat =>
      'Este formato de imagen no es compatible. Conviértelo a PNG, JPEG o WebP e inténtalo de nuevo.';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'Las imágenes HEIC, SVG y TIFF aún no son compatibles. Convierta la imagen a PNG, JPEG o WebP e inténtelo de nuevo.';

  @override
  String get ocrImageDecodeFailed =>
      'La imagen está dañada o no se puede decodificar. Selecciónelo nuevamente o conviértalo a PNG, JPEG o WebP e inténtelo nuevamente.';

  @override
  String get ocrImageDimensionsTooLarge =>
      'La resolución de la imagen es demasiado grande. OCR admite hasta 50 millones de píxeles por imagen. Cambie su tamaño e inténtelo de nuevo.';

  @override
  String get ocrImageOrientationPngTooLarge =>
      'El PNG necesario para corregir la orientación de esta imagen excedería el límite de tamaño de la solicitud de OCR. Cambie el tamaño de la imagen e inténtelo de nuevo.';

  @override
  String get ocrImageOrientationFailed =>
      'No se pudo corregir la orientación de la imagen. Conviértelo a PNG, JPEG o WebP e inténtalo de nuevo.';

  @override
  String get ocrImagePreparationFailed =>
      'La imagen no se pudo procesar. Selecciónelo nuevamente e inténtelo nuevamente.';

  @override
  String get homeTitle => 'Hogar';

  @override
  String get homeWelcome => 'Bienvenido a Stroom';

  @override
  String get homeChooseModule => 'Elija un módulo para comenzar';

  @override
  String get homeOcrSubtitle => 'Reconocimiento de texto';

  @override
  String get homeAsrTitle => 'reconocimiento de voz';

  @override
  String get homeAsrSubtitle => 'Discurso a texto';

  @override
  String get homeWebDownloadTitle => 'Descargar medios web';

  @override
  String get homeWebDownloadSubtitle =>
      'Descargar audio y vídeo de páginas web.';

  @override
  String get homeAudioSeparationTitle => 'Separación de audio';

  @override
  String get homeAudioSeparationSubtitle => 'Extraer audio de vídeo';

  @override
  String get homeTtsTitle => 'Texto a voz';

  @override
  String get homeTtsSubtitle => 'Convertir texto a voz';

  @override
  String get homeChartsTitle => 'Creador de gráficos';

  @override
  String get homeChartsSubtitle => 'Editor de gráficos de sirena';

  @override
  String get homeMathTitle => 'trazado matemático';

  @override
  String get homeMathSubtitle => 'Funciones de trazado';

  @override
  String get homeAnkiTitle => 'Tarjetas didácticas de Anki';

  @override
  String get homeAnkiSubtitle => 'Sistema de ayuda a la memoria';

  @override
  String get homeTaskFlowTitle => 'Flujos de tareas';

  @override
  String get homeTaskFlowEmpty =>
      'Cree un flujo automatizado para ejecutar varios módulos en secuencia';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flujos de tareas · Administrar',
      one: '$count flujo de tareas · Administrar',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => 'Tareas recientes';

  @override
  String get homeViewAll => 'Ver todo';

  @override
  String get statusInProgress => 'En curso';

  @override
  String get statusCompleted => 'Terminado';

  @override
  String get statusFailed => 'Fallido';

  @override
  String get navHome => 'Hogar';

  @override
  String get navChat => 'Charlar';

  @override
  String get navFiles => 'Archivos';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get conversationsTitle => 'Historial de conversaciones';

  @override
  String get conversationNew => 'Nueva conversación';

  @override
  String get conversationSelectTitle => 'Elige una conversación';

  @override
  String get topicSelectionEmptyTitle => 'Aún no hay conversaciones';

  @override
  String get topicSelectionEmptyMessage =>
      'Crea una nueva conversación para comenzar';

  @override
  String get topicSelectionNewTopic => 'Nueva conversación';

  @override
  String get topicSelectionNoAssistant => 'Ningún asistente seleccionado';

  @override
  String get topicSelectionBackToAssistants =>
      'Volver a la selección de asistente';

  @override
  String get topicSelectionEditAssistant => 'Asistente de edición';

  @override
  String get topicSelectionReorderHint =>
      'Mantenga presionado y arrastre para reordenar las conversaciones';

  @override
  String conversationDeleteNamed(String title) {
    return '¿Eliminar la conversación “$title”? Esto no se puede deshacer.';
  }

  @override
  String get conversationDeleteTitle => 'Eliminar conversación';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '¿Eliminar las conversaciones seleccionadas ($count)? Esta acción no se puede deshacer.',
      one:
          '¿Eliminar la conversación seleccionada ($count)? Esta acción no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Borrar';

  @override
  String get conversationRename => 'Cambiar el nombre de la conversación';

  @override
  String get conversationRenameHint => 'Introduzca un nuevo nombre';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get conversationNoMatches =>
      'No se encontraron conversaciones coincidentes';

  @override
  String get conversationEmpty => 'Sin historial de conversaciones';

  @override
  String get conversationSearchHint =>
      'Buscar mensajes en todas las conversaciones...';

  @override
  String conversationSelected(int count) {
    return '$count seleccionado';
  }

  @override
  String get conversationSearch => 'Buscar';

  @override
  String get conversationDeleteSelected => 'Eliminar seleccionado';

  @override
  String get actionUnselect => 'Cancelar selección';

  @override
  String get actionSelect => 'Seleccionar';

  @override
  String conversationDeleteCount(int count) {
    return 'Eliminar $count';
  }

  @override
  String get conversationPin => 'Alfiler';

  @override
  String get conversationUnpin => 'Desprender';

  @override
  String get actionRename => 'Rebautizar';

  @override
  String get conversationAutoRename => 'Nombre automático';

  @override
  String get conversationTemporary => 'conversación temporal';

  @override
  String get conversationCloseTemporary => 'Cerrar conversación temporal';

  @override
  String get taskListTitle => 'lista de tareas';

  @override
  String get taskListEmpty => 'Sin tareas';

  @override
  String get unifiedTaskListTabAll => 'Todo';

  @override
  String get unifiedTaskListTabInProgress => 'En curso';

  @override
  String get unifiedTaskListTabCompleted => 'Terminado';

  @override
  String get unifiedTaskListTabFailed => 'Fallido';

  @override
  String get unifiedTaskListTabStopped => 'Interrumpido';

  @override
  String get unifiedTaskListConfirmClear => 'Confirmar claro';

  @override
  String get unifiedTaskListConfirmClearFailedMessage =>
      '¿Está seguro de que desea borrar todas las tareas fallidas?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      '¿Estás seguro de que deseas borrar todas las tareas? Esta acción no se puede deshacer.';

  @override
  String get unifiedTaskListCancel => 'Cancelar';

  @override
  String get unifiedTaskListConfirm => 'Confirmar';

  @override
  String get unifiedTaskListClearCompleted => 'Borrar tareas completadas';

  @override
  String get unifiedTaskListClearFailed => 'Borrar tareas fallidas';

  @override
  String get unifiedTaskListClearAll => 'Borrar todas las tareas';

  @override
  String get unifiedTaskListRestoreInProgress =>
      'Restaurando registros de flujo de tareas...';

  @override
  String get unifiedTaskListRestoreFailed =>
      'No se pudieron leer los registros de flujo de tareas; las acciones de la tarea están en pausa';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return 'Borrar incompleto: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning =>
      'El flujo de tareas sigue ejecutándose después de la cancelación.';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      'No se pudo guardar el estado de cancelación del flujo de tareas. Vuelva a intentar borrar.';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      'No se pudo guardar la eliminación de registros de flujo de tareas. Vuelva a intentar borrar.';

  @override
  String get chatAutoContinuePrompt => 'Continúe si no ha terminado.';

  @override
  String get chatSearchCurrent => 'Buscar esta conversación...';

  @override
  String get chatSearchAll => 'Buscar todas las conversaciones...';

  @override
  String get searchPrevious => 'Partido anterior';

  @override
  String get searchNext => 'Próximo partido';

  @override
  String get searchClose => 'Cerrar búsqueda';

  @override
  String get searchCurrentConversation => 'Conversación actual';

  @override
  String get searchAllConversations => 'Todas las conversaciones';

  @override
  String get chatReasoning => 'Razonamiento';

  @override
  String get chatTools => 'Herramientas';

  @override
  String get chatCustomParameters => 'Parámetros personalizados';

  @override
  String get chatEditMessage => 'Editar mensaje';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get chatEditWarning =>
      'Todos los mensajes a continuación se perderán cuando los edites y los reenvíes.';

  @override
  String get chatAttachment => 'Adjunto';

  @override
  String get chatMessageHint => 'Introduce un mensaje...';

  @override
  String get chatFullscreenEdit => 'Editor de pantalla completa';

  @override
  String get chatStopGeneration => 'dejar de generar';

  @override
  String get actionSend => 'Enviar';

  @override
  String get chatCopy => 'Copiar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionRetry => 'Rever';

  @override
  String get actionEdit => 'Editar';

  @override
  String get chatViewResponseData => 'Ver datos de respuesta';

  @override
  String get chatViewRequestData => 'Ver datos de la solicitud';

  @override
  String get chatInspectJson => 'Inspeccionar JSON';

  @override
  String get chatConfirmEditTitle => 'Editar mensaje';

  @override
  String get chatConfirmEditDeleteFollowing =>
      '¿Editar este mensaje? Este mensaje y todos los mensajes siguientes serán eliminados.';

  @override
  String get chatConfirmResend => '¿Reenviar este mensaje?';

  @override
  String get chatConfirmRetryTitle => 'Rever';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      '¿Reintentar esta respuesta? Este mensaje y todos los mensajes siguientes serán eliminados.';

  @override
  String get chatConfirmRegenerate => '¿Regenerar la respuesta?';

  @override
  String get chatDeleteMessageTitle => 'Eliminar mensaje';

  @override
  String get chatDeleteMessageConfirm =>
      '¿Eliminar este mensaje? Esto no se puede deshacer.';

  @override
  String get chatThinking => 'Pensamiento';

  @override
  String get chatThinkingComplete => 'Pensamiento';

  @override
  String get conversationDeleteOne =>
      '¿Eliminar esta conversación? Esto no se puede deshacer.';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Recursos $selected/$total seleccionados',
      one: 'Recurso $selected/$total seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => 'Seleccione medios para descargar';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ocultar $count segmentos',
      one: 'Ocultar $count segmento',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count segmentos',
      one: 'Mostrar $count segmento',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => 'No se detectaron recursos';

  @override
  String get mediaSegment => 'Segmento';

  @override
  String get mediaPlaylist => 'Lista de reproducción';

  @override
  String get mediaFullVideo => 'vídeo completo';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours horas $minutes minutos $seconds segundos';
  }

  @override
  String mediaDuration(String value) {
    return 'Duración: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return 'Resolución: ${width}x$height';
  }

  @override
  String get mediaPreview => 'Avance';

  @override
  String get mediaSegmentPreviewHint =>
      'Vista previa de segmentos de la lista de reproducción';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargar $count recursos seleccionados',
      one: 'Descargar $count recurso seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => 'Confirmar descarga';

  @override
  String get chatNoMoreHistory => 'No más mensajes';

  @override
  String get chatSendFailed => 'No se pudo enviar el mensaje';

  @override
  String get chatViewErrorDetails => 'Ver detalles del error';

  @override
  String get chatCompactionCollapsed =>
      'Contexto compactado · mensajes antiguos resumidos (haga clic para contraer)';

  @override
  String get chatCompactionExpanded =>
      'Contexto compactado · mensajes antiguos resumidos (haga clic para ver el resumen)';

  @override
  String get chatEditConversationTitle => 'Editar título de conversación';

  @override
  String get chatSearchMessages => 'Buscar mensajes';

  @override
  String get chatApiMissingSettings =>
      '⚠️ La API de chat no está configurada: ve a Configuración';

  @override
  String get appSettings => 'Ajustes';

  @override
  String get chatCopied => 'Copiado';

  @override
  String get chatNoSavableText => 'No hay texto para guardar';

  @override
  String get chatSaveMarkdownTitle => 'Guardar mensaje como Markdown';

  @override
  String get chatSaveToolCallChoice =>
      'Esta respuesta contiene varias llamadas a herramientas. Elige qué guardar:';

  @override
  String get chatSaveCompleteMessage => 'Guardar mensaje completo';

  @override
  String get chatSaveLastMessage => 'Guardar último mensaje';

  @override
  String get chatSaveToAppFiles => 'Guardar en archivos de aplicaciones';

  @override
  String get chatSaveFolderHint =>
      'Elija o cree una carpeta para el archivo .md';

  @override
  String get chatSaveFilenameHint =>
      'Ingrese un nombre de archivo (.md se agrega automáticamente)';

  @override
  String get chatFilenameRequired =>
      'El nombre del archivo no puede estar vacío.';

  @override
  String chatSavedToPath(String path) {
    return 'Guardado en: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return 'Guardado en archivos de aplicación: $path';
  }

  @override
  String get chatSelectModel => 'Selecciona un modelo';

  @override
  String get chatModelFallback => 'Modelo';

  @override
  String get chatNoModelsAvailable => 'No hay modelos disponibles';

  @override
  String get chatAvailableTools => 'Herramientas disponibles';

  @override
  String get chatNoToolsAvailable => 'No hay herramientas disponibles';

  @override
  String get chatReasoningSettings => 'Configuración de razonamiento';

  @override
  String get chatReasoningNotConfigured =>
      'No hay parámetros de razonamiento configurados para este modelo. Agréguelos en la configuración del modelo.';

  @override
  String get chatReasoningEffort => 'esfuerzo de razonamiento';

  @override
  String get chatReasoningEffortNotConfigured =>
      'No hay ningún parámetro de esfuerzo de razonamiento configurado para este modelo. Agréguelo en la configuración del modelo.';

  @override
  String get chatParameterNoOptions =>
      'Este parámetro no tiene valores de opción. Agréguelos en la configuración del modelo.';

  @override
  String get chatOtherReasoningNotConfigured =>
      'No se configuran otros parámetros de razonamiento para este modelo.\nAgréguelos en la configuración del modelo.';

  @override
  String get chatCustomParamsNotConfigured =>
      'No hay parámetros personalizados configurados para este modelo.\nAgréguelos en la configuración del modelo.';

  @override
  String get chatNoOptionValues =>
      'Sin valores de opción. Agréguelos en la configuración del modelo.';

  @override
  String get chatImageLoadFailed => 'No se puede cargar la imagen';

  @override
  String get chatVideoLoadFailed => 'No se puede cargar el vídeo';

  @override
  String get chatHtmlLoading => 'Cargando vista previa HTML...';

  @override
  String get chatPreviewLoadFailed => 'No se pudo cargar la vista previa';

  @override
  String get albumPickerLoadFailed =>
      'No se puede cargar el álbum de la aplicación';

  @override
  String get chatHtmlPreview => 'Vista previa HTML';

  @override
  String get chatMermaidLoading => 'Cargando vista previa del gráfico...';

  @override
  String get chatMermaidPreview => 'Vista previa de sirena';

  @override
  String get chatZoomOut => 'alejar';

  @override
  String get chatZoomIn => 'Dar un golpe de zoom';

  @override
  String get chatJsonInspection => 'inspección JSON';

  @override
  String get chatNoRequestData => 'Sin datos de solicitud';

  @override
  String get chatNoResponseData => 'Sin datos de respuesta';

  @override
  String get chatSaveMessage => 'Guardar mensaje';

  @override
  String get chatChooseSaveLocation => 'Elige dónde guardar el mensaje';

  @override
  String get chatChooseSaveLocationLabel => 'Elija una ubicación para guardar:';

  @override
  String get chatSaveAppFile => 'Guardar en archivos de aplicaciones';

  @override
  String get chatSaveDevice => 'Guardar en dispositivo';

  @override
  String get chatFileTypeAudio => 'archivo de audio';

  @override
  String get chatFileTypeVideo => 'archivo de vídeo';

  @override
  String get chatFileTypeDocument => 'Documento';

  @override
  String get chatFileTypeGeneric => 'Archivo';

  @override
  String get chatInfoType => 'Tipo';

  @override
  String get chatInfoSize => 'Tamaño';

  @override
  String get chatInfoPath => 'Camino';

  @override
  String get chatErrorBack => 'Atrás';

  @override
  String get chatErrorPrefix => 'Error:';

  @override
  String get chatErrorCancelled => 'La salida fue interrumpida por el usuario.';

  @override
  String get chatErrorProviderNotConfigured =>
      'La API de chat no está configurada. Abra Configuración para configurar un proveedor.';

  @override
  String get chatErrorApiKeyNotConfigured =>
      'La clave API no está configurada. Verifique la configuración.';

  @override
  String get chatErrorServerConnection =>
      'No se puede conectar con el servidor. Verifique su conexión de red y dirección API.';

  @override
  String get chatErrorNetworkConnection =>
      'La conexión de red falló. Verifique su conexión de red.';

  @override
  String get chatErrorTimeout =>
      'Se agotó el tiempo de conexión. El servidor no respondió.';

  @override
  String chatAttachmentImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return 'No se pudo tomar una foto: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform no admite el acceso a la galería del dispositivo: $error';
  }

  @override
  String get chatAttachmentWebPlatform => 'navegador web';

  @override
  String get chatAttachmentCurrentPlatform => 'este dispositivo';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      'Conceda permiso de acceso a la biblioteca de fotografías e inténtelo de nuevo.';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      'Permita que este sitio web acceda a archivos en la configuración de su navegador.';

  @override
  String get chatAttachmentGalleryFallbackHint =>
      'Verifique que su dispositivo admita la selección de galería.';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return 'No se pudo importar la imagen: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform no admite la selección de archivos: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint =>
      'Conceda permiso de acceso al archivo e inténtelo de nuevo.';

  @override
  String get chatAttachmentFileFallbackHint =>
      'Verifique que su dispositivo admita la selección de archivos.';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return 'No se pudo importar el archivo: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return 'Importado $fileName';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return 'No se pudo guardar la imagen editada: $error';
  }

  @override
  String get chatDataDetails => 'Detalles de datos';

  @override
  String get chatErrorDetailOcrDiagnostics => 'Diagnóstico OCR';

  @override
  String get chatErrorDetailRequestUrl => 'Solicitar URL';

  @override
  String get chatErrorDetailRequestHeaders => 'Encabezados de solicitud';

  @override
  String get chatErrorDetailRequestBody => 'Cuerpo de solicitud';

  @override
  String get chatErrorDetailStatusCode => 'Código de estado';

  @override
  String get chatErrorDetailResponseHeaders => 'Encabezados de respuesta';

  @override
  String get chatErrorDetailResponseBody => 'Cuerpo de respuesta';

  @override
  String get chatErrorDetailEmpty => 'No hay datos detallados disponibles';

  @override
  String get chatAudioPreviewClose => 'Cerrar';

  @override
  String get chatPreviewClose => 'Cerrar vista previa';

  @override
  String get actionBack => 'Atrás';

  @override
  String get chatCannotLoadFile => 'No se puede cargar el archivo';

  @override
  String chatThinkingNumbered(int index) {
    return 'Pensando $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '¿Descartar los cambios no guardados?';

  @override
  String get taskFlowUiDiscardBody =>
      'Todos los cambios no guardados se perderán si regresa.';

  @override
  String get taskFlowUiContinueEditing => 'Continuar editando';

  @override
  String get taskFlowUiDiscard => 'Desechar';

  @override
  String get taskFlowUiUndo => 'Deshacer';

  @override
  String get taskFlowUiSave => 'Guardar';

  @override
  String get taskFlowUiNameHint => 'Introduzca un nombre de flujo de tareas';

  @override
  String get taskFlowUiDescriptionHint => 'Añade una descripción (opcional)';

  @override
  String get taskFlowUiNameRequired =>
      'Introduzca un nombre de flujo de tareas';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return 'Paso $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return 'Se requiere “$parameter” para “$block”';
  }

  @override
  String get taskFlowUiSaveFailed =>
      'No se pudo guardar. Tus cambios todavía están aquí. Intentar otra vez.';

  @override
  String get taskFlowUiRetry => 'Rever';

  @override
  String get taskFlowUiUpdated => 'Flujo de tareas actualizado';

  @override
  String get taskFlowUiCreated => 'Flujo de tareas creado';

  @override
  String get taskFlowUiTitle => 'Flujo de tareas';

  @override
  String get taskFlowUiNotFound => 'Tarea no encontrada';

  @override
  String get taskFlowUiBack => 'Atrás';

  @override
  String get taskFlowUiEdit => 'Editar';

  @override
  String taskFlowUiInput(Object label) {
    return 'Entrada ($label)';
  }

  @override
  String get taskFlowUiInputHint => 'Introduzca texto o un enlace';

  @override
  String get taskFlowUiStart => 'Iniciar flujo de tareas';

  @override
  String get taskFlowUiNoInput =>
      'Aún no hay entradas. Toque a continuación para agregar una URL de recurso web.';

  @override
  String get taskFlowUiAddResource => 'Agregar recurso web';

  @override
  String get taskFlowUiUrlHint =>
      'Ingrese la URL de una página web de video o audio';

  @override
  String get taskFlowUiDeleteInput => 'Eliminar esta entrada';

  @override
  String get taskFlowUiHour => 'hora';

  @override
  String get taskFlowUiMinute => 'mín.';

  @override
  String get taskFlowUiSecond => 'segundo';

  @override
  String get taskFlowUiPreview => 'Avance:';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      'Opcional: filtre los recursos de vídeo por duración. Déjelo en blanco para mostrar todos los recursos disponibles.';

  @override
  String get taskFlowUiSelectImages => 'Seleccionar imágenes (múltiples)';

  @override
  String get taskFlowUiSelectAudio => 'Seleccionar audio (múltiple)';

  @override
  String get taskFlowUiSelectFiles => 'Seleccionar archivos (múltiples)';

  @override
  String get taskFlowUiSelectVideo => 'Seleccionar videos (múltiples)';

  @override
  String get taskFlowUiRemove => 'Eliminar';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return 'No se pudo limpiar el archivo eliminado: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0. Entrada inicial';

  @override
  String taskFlowUiInputType(Object type) {
    return 'Tipo de entrada: $type';
  }

  @override
  String get taskFlowUiUserFlowInput =>
      'Entrada proporcionada cuando el usuario ejecuta el flujo de tareas';

  @override
  String taskFlowUiBlockInput(Object type) {
    return 'Entrada: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return 'Salida: $type';
  }

  @override
  String get taskFlowUiParameters => 'Parámetros:';

  @override
  String get taskFlowUiClose => 'Cerrar';

  @override
  String get taskFlowUiSelectAppImages =>
      'Seleccione imágenes de la aplicación (múltiples)';

  @override
  String get taskFlowUiNoImages => 'Sin imágenes';

  @override
  String get taskFlowUiSelectAppAudio =>
      'Seleccione audio de la aplicación (múltiples)';

  @override
  String get taskFlowUiNoAudio => 'Sin audio';

  @override
  String get taskFlowUiSelectAppVideo =>
      'Seleccionar videos de la aplicación (múltiples)';

  @override
  String get taskFlowUiNoVideo => 'Sin vídeos';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return 'No se pudo seleccionar el archivo: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '“$name” supera $limit MB. Elija un archivo más pequeño.';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '“$name” está vacío o es ilegible';
  }

  @override
  String get taskFlowUiSomeFilesMissing =>
      'Faltan algunos archivos y se omitieron';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return 'No se puede acceder a los archivos seleccionados $count. Seleccione todos los archivos nuevamente.';
  }

  @override
  String get taskFlowUiQueuedOne => 'Flujo de tareas agregado a la cola';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return 'Se agregaron flujos de tareas $count a la cola';
  }

  @override
  String get taskFlowUiRunTitle => 'Esta carrera';

  @override
  String get taskFlowUiCancelBatch => 'Cancelar lote completo';

  @override
  String get taskFlowUiRestoringRecords =>
      'Restaurando registros de flujo de tareas...';

  @override
  String get taskFlowUiRecordsPaused =>
      'No se pudieron cargar los registros de flujo de tareas. Las acciones de las tareas están en pausa.';

  @override
  String get taskFlowUiRecordsCleared =>
      'Se han borrado los registros de esta ejecución.';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return 'Ejecuciones $finished de $total finalizadas';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return '· Registros $count borrados';
  }

  @override
  String get taskFlowUiTemporaryFiles => 'Archivos intermedios temporales';

  @override
  String get taskFlowUiAddBlock => 'Agregar bloque';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return 'Insertar bloque antes del paso $index';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      'Ningún bloque es compatible con ambos escalones adyacentes. Primero ajuste los escalones adyacentes.';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return 'Insertar antes del paso $index';
  }

  @override
  String get taskFlowUiUnknown => 'Desconocido';

  @override
  String get taskFlowUiChooseBlock => 'Elige un bloque';

  @override
  String get taskFlowUiInsertBlock => 'Insertar bloque';

  @override
  String get taskFlowUiPreviousOutput => 'Salida del paso anterior';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '; el siguiente paso necesita: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock =>
      'Ningún bloque es compatible con el tipo actual';

  @override
  String get taskFlowUiReplaceBlock => 'Reemplazar bloque';

  @override
  String get taskFlowUiBlockCompatibility =>
      'Solo puedes reemplazarlo con un bloque que tenga tipos de entrada y salida compatibles.';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      'La limpieza después del siguiente paso guarda el resultado correctamente; El paso final siempre se mantiene.';

  @override
  String get taskFlowUiSetParameters => 'Establecer parámetros';

  @override
  String get taskFlowUiReplace => 'Reemplazar';

  @override
  String get taskFlowUiViewParameters => 'Toque para ver los parámetros';

  @override
  String get taskFlowUiTapSetParameters =>
      'Toque para configurar los parámetros';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return 'Bloque desconocido: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered =>
      'Este tipo de bloque no está registrado';

  @override
  String taskFlowUiStepActions(Object index) {
    return 'Acciones para el paso $index';
  }

  @override
  String get taskFlowUiInsertBefore => 'Insertar antes';

  @override
  String get taskFlowUiInsertAfter => 'Insertar después';

  @override
  String get taskFlowUiCopyBlock => 'Bloque duplicado';

  @override
  String get taskFlowUiMoveUp => 'Subir';

  @override
  String get taskFlowUiMoveUpDisabled => 'Subir (ya es el primero)';

  @override
  String get taskFlowUiMoveDown => 'Bajar';

  @override
  String get taskFlowUiMoveDownDisabled =>
      'Mover hacia abajo (ya es el último)';

  @override
  String get taskFlowUiDeleteBlock => 'Eliminar bloque';

  @override
  String taskFlowUiInputLabel(Object label) {
    return 'Entrada: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return 'Salida: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return 'El tipo de bloque “$name” no está registrado';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return 'Configuración de $label';
  }

  @override
  String get taskFlowUiSendToAssistant =>
      'El mensaje de usuario enviado al asistente es el resultado del paso anterior.';

  @override
  String get taskFlowUiTempSpaceInfo =>
      'Este paso sale al espacio temporal del flujo. Su salida se limpia después de que el siguiente paso se guarde correctamente. La carpeta de guardado original se conserva y restaura cuando el modo temporal está desactivado.';

  @override
  String get taskFlowUiNoExtraParameters =>
      'Este bloque no tiene parámetros adicionales';

  @override
  String get taskFlowUiCancel => 'Cancelar';

  @override
  String get taskFlowUiConfirm => 'Confirmar';

  @override
  String get taskFlowUiConfigureModelFirst => 'Configurar un modelo primero';

  @override
  String get taskFlowUiModelUnavailable =>
      'No se ha seleccionado ningún modelo o el modelo no está disponible. Seleccione otro modelo.';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return 'Modelo $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => 'Proveedor sin nombre';

  @override
  String get taskFlowUiCustomModelParameters =>
      'Parámetros del modelo personalizado';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      'Ningún modelo TTS tiene voces configuradas. Puede ingresar una identificación manualmente.';

  @override
  String get taskFlowUiVoiceUnavailable =>
      'La voz no está disponible. Seleccione otra voz.';

  @override
  String get taskFlowUiSelectVoice => 'Seleccione una voz';

  @override
  String get taskFlowUiAssistantUnavailable => 'Asistente no disponible';

  @override
  String get taskFlowUiAssistantUseCurrent =>
      'No especificado (use el asistente seleccionado actualmente)';

  @override
  String get taskFlowUiAssistantDeleted =>
      'El asistente configurado fue eliminado. Seleccione otro asistente.';

  @override
  String get taskFlowUiChooseAssistant => 'Elige un asistente';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      'Solo se puede seleccionar “Mis asistentes” (agregue uno en “Chat → Asistentes”)';

  @override
  String get taskFlowUiMyAssistants => 'Mis asistentes';

  @override
  String get taskFlowUiNoCustomAssistants =>
      'Aún no hay asistentes personalizados. Crea uno en “Chat → Asistentes”.';

  @override
  String get taskFlowUiYes => 'Sí';

  @override
  String get taskFlowUiNo => 'No';

  @override
  String get taskFlowUiDefaultRoot => 'Predeterminado (carpeta raíz)';

  @override
  String get taskFlowUiSelect => 'Seleccionar';

  @override
  String get taskFlowUiSelectSaveFolder => 'Elija una carpeta para guardar';

  @override
  String get taskFlowUiCatCatchVideo => 'Video';

  @override
  String get taskFlowUiCatCatchAudio => 'Audio';

  @override
  String get taskFlowUiCatCatchEither =>
      'Vídeo o audio (filtro basado en pasos posteriores)';

  @override
  String get taskFlowUiManual => 'Manual';

  @override
  String get taskFlowUiAutomatic => 'Automático';

  @override
  String get taskFlowUiAutomaticPrompt => 'Automático con confirmación';

  @override
  String get taskFlowUiEditTitle => 'Editar flujo de tareas';

  @override
  String get taskFlowUiCreateTitle => 'Nuevo flujo de tareas';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return 'Paso $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return 'Tipo de entrada: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return 'Entrada: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return 'Salida: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return 'No se pudo limpiar el archivo eliminado: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return 'No se pudo seleccionar el archivo: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '“$name” supera $limit MB. Elija un archivo más pequeño.';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '“$name” está vacío o es ilegible';
  }

  @override
  String get taskFlowUiTemporary => 'Temporario';

  @override
  String get taskFlowUiTemporaryFileHint =>
      'Archivo temporal (limpiado después de que el siguiente paso sea exitoso)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return 'El tipo de bloque “$name” no está registrado';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return 'Ejecuciones $finished de $total finalizadas';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return '· Registros $count borrados';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return 'Entrada: $input → Salida: $output';
  }

  @override
  String get taskFlowCardTag => 'Flujo de tareas';

  @override
  String get taskFlowCardQueued => 'En cola (esperando recursos)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done de $total completado';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count $label';
  }

  @override
  String get taskFlowCardFailedLabel => 'fallido';

  @override
  String get taskFlowCardSkippedLabel => 'saltado';

  @override
  String get taskFlowCardCancelledLabel => 'cancelado';

  @override
  String get taskFlowCardInterruptedLabel => 'interrumpido';

  @override
  String get taskFlowCardCancelFlow => 'Cancelar flujo';

  @override
  String get taskFlowCardRetry => 'Rever';

  @override
  String get taskFlowCardCancelBatch => 'Cancelar lote completo';

  @override
  String get taskFlowCardDelete => 'Borrar';

  @override
  String get taskFlowCardRetryFlow => 'Reintentar el flujo de tareas';

  @override
  String get taskFlowCardNoSnapshot =>
      'Esta ejecución no tiene instantánea. Comenzará de nuevo utilizando la configuración de flujo actual.';

  @override
  String get taskFlowCardRetryInfo =>
      'Comenzar de nuevo descarga archivos y llama a los modelos nuevamente. Vuelva a intentarlo con la configuración utilizada en el inicio o elija explícitamente la configuración más reciente. Para reutilizar los pasos completados, elija \"Reanudar desde el paso interrumpido\".';

  @override
  String get taskFlowCardRunLatest => 'Ejecutar con la última configuración';

  @override
  String get taskFlowCardRetryOriginal =>
      'Reintentar con la configuración original';

  @override
  String get taskFlowCardDeleteRecord => 'Eliminar registro de flujo de tareas';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      'Eliminar esta ejecución cancelará las tareas inacabadas en el lote y borrará sus registros de subtareas. ¿Borrar?';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      'Este flujo está funcionando. Eliminarlo cancelará sus tareas activas. ¿Borrar?';

  @override
  String get taskFlowCardDeleteRecordConfirm =>
      '¿Eliminar este registro de flujo y sus registros de subtarea?';

  @override
  String get taskFlowCardDeleteConfirm => '¿Eliminar este registro de flujo?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      'No se pudo guardar el estado de cancelación del flujo. Intente eliminar nuevamente.';

  @override
  String get taskFlowCardStillRunning =>
      'El flujo sigue funcionando después de la cancelación.';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      'No se pudo guardar el estado de eliminación del registro de flujo. Intente eliminar nuevamente.';

  @override
  String get taskFlowCardConfirm => 'Confirmar';

  @override
  String get taskFlowCardWaiting => 'Espera';

  @override
  String get taskFlowCardRunning => 'Correr';

  @override
  String get taskFlowCardPaused => 'En pausa';

  @override
  String get taskFlowCardCompleted => 'Terminado';

  @override
  String get taskFlowCardFailed => 'Fallido';

  @override
  String get taskFlowCardCanceled => 'Cancelado';

  @override
  String get taskFlowCardInterrupted => 'interrumpido';

  @override
  String get taskFlowCardSucceeded => 'Saltado';

  @override
  String get taskFlowCardPause => 'Pausar el flujo';

  @override
  String get taskFlowCardResume => 'Reanudar flujo';

  @override
  String get taskFlowCardResumeInterrupted =>
      'Reanudar desde el paso interrumpido';

  @override
  String get taskFlowCardCancel => 'Cancelar';

  @override
  String get unifiedTaskType => 'Tipo de tarea';

  @override
  String get unifiedTaskCreatedAt => 'Creado';

  @override
  String get unifiedTaskCompletedAt => 'Terminado';

  @override
  String get unifiedTaskResultStatus => 'Estado del resultado';

  @override
  String get unifiedTaskPartialResult =>
      'Resultado parcial; el contenido puede estar incompleto';

  @override
  String get unifiedTaskErrorDetails => 'Detalles del error';

  @override
  String get unifiedTaskViewErrorDetails => 'Ver detalles del error';

  @override
  String get unifiedTaskOcrPerImage => 'Reconocer cada imagen';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return 'Imagen $index';
  }

  @override
  String get unifiedTaskOcrPending => 'esperando reconocer';

  @override
  String get unifiedTaskOcrRunning => 'Reconociendo';

  @override
  String get unifiedTaskCompleted => 'Terminado';

  @override
  String get unifiedTaskIncomplete => 'resultado incompleto';

  @override
  String get unifiedTaskOcrFailed => 'El reconocimiento falló';

  @override
  String get unifiedTaskCancelled => 'Cancelado';

  @override
  String get unifiedTaskWaitingStart => 'Esperando empezar...';

  @override
  String get unifiedTaskSteps => 'Pasos';

  @override
  String get unifiedTaskStartNow => 'Empezar ahora';

  @override
  String get unifiedTaskOpenFile => 'Abrir archivo';

  @override
  String get unifiedTaskRetrySave => 'Reintentar guardar solo';

  @override
  String get unifiedTaskRetryPartialSave =>
      'Reintentar guardar solo el resultado parcial';

  @override
  String get unifiedTaskSavePartialResult => 'Guardar resultado parcial';

  @override
  String get unifiedTaskRetry => 'Rever';

  @override
  String get unifiedTaskCancel => 'Cancelar';

  @override
  String get unifiedTaskDelete => 'Borrar';

  @override
  String get unifiedTaskFormatUnsupported =>
      'La vista previa no es compatible con este formato';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return 'Error de carga: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return 'Error de reproducción: $error';
  }

  @override
  String get unifiedTaskAudioFile => 'archivo de audio';

  @override
  String get unifiedTaskPreviewLoadFailed =>
      'No se pudo cargar la vista previa';

  @override
  String get unifiedTaskUnknownSize => 'Tamaño desconocido';

  @override
  String get unifiedTaskUnnamedRecording => 'Grabación sin título';

  @override
  String get unifiedTaskPause => 'Pausa';

  @override
  String get unifiedTaskClearTask => 'Borrar tarea';

  @override
  String get unifiedTaskContinue => 'Continuar';

  @override
  String get unifiedTaskRemoveFromList => 'Eliminar de la lista';

  @override
  String get unifiedTaskSynthesisText => 'Texto sintetizado';

  @override
  String get unifiedTaskStatus => 'Estado';

  @override
  String get unifiedTaskDetails => 'Detalles';

  @override
  String get unifiedTaskSynthesisError => 'Detalles del error de síntesis';

  @override
  String get unifiedTaskClose => 'Cerrar';

  @override
  String get unifiedTaskRawRequestResponse =>
      'Solicitud y respuesta sin procesar';

  @override
  String get unifiedTaskRawRequestBody => 'Cuerpo de solicitud sin formato:';

  @override
  String get unifiedTaskRawResponseBody => 'Cuerpo de respuesta sin procesar:';

  @override
  String get commonJustNow => 'En este momento';

  @override
  String commonMinutesAgo(Object count) {
    return '$count hace minutos';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count hace horas';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds seg.';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds seg';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get unifiedTaskTypeOcr => 'Reconocimiento de texto de imagen';

  @override
  String get unifiedTaskTypeAsr => 'Transcripción de audio';

  @override
  String get unifiedTaskTypeAudioSeparation => 'Separación de audio';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return 'OCR: $basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return 'Separación de audio: $basename';
  }

  @override
  String get unifiedTaskTypeChat => 'Chat asistente';

  @override
  String get unifiedTaskPlayAudio => 'Reproducir audio';

  @override
  String get unifiedTaskPauseAudio => 'Pausar audio';

  @override
  String get catcatchFlowActionNotStarted =>
      'La acción de flujo no comenzó. Verifique el estado del flujo e inténtelo nuevamente.';

  @override
  String catcatchFlowActionFailed(Object error) {
    return 'Error en la acción de flujo: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      'Se agotó el tiempo de espera para el escaneo automático de páginas. Inicie sesión o configure un script de usuario en esta página; Después de que se detecte el medio, elija Continuar flujo.';

  @override
  String get browserRecoveryContinue => 'Continuar flujo';

  @override
  String get catcatchSkipped => 'Omitido (nada que procesar)';

  @override
  String catCatchDetailMediaResources(Object count) {
    return 'Se encontraron recursos multimedia $count';
  }

  @override
  String catCatchDetailResources(Object count) {
    return 'Recursos $count encontrados';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return 'El navegador encontró recursos $count';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return 'Recursos $total encontrados (segmentos de lista de reproducción $segments)';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return 'Se encontraron recursos $count. Elige uno.';
  }

  @override
  String get catCatchDetailAutoSelectFirst =>
      'Se seleccionó automáticamente el resultado 1 y se inició la descarga.';

  @override
  String get catCatchDetailAutoSelectRemaining =>
      'Queda 1 resultado; comenzó a descargarse automáticamente';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return 'Se omitió la conversión para .$extension; este formato no necesita conversión';
  }

  @override
  String get catCatchDetailSkipNoExtension =>
      'Se omitió la conversión; este formato no necesita conversión';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return 'Después de filtrar $duration, los resultados de $remaining permanecen (se excluyen los recursos no coincidentes de $removed)';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return 'Todos los recursos $count coinciden con el filtro de duración $duration';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '${count}h';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '${count}m';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count';
  }

  @override
  String get catcatchRetryStep => 'Vuelva a intentar este paso';

  @override
  String catcatchCollapseSegments(Object count) {
    return 'Ocultar segmentos $count';
  }

  @override
  String catcatchShowSegments(Object count) {
    return 'Mostrar segmentos $count';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '$selected de recursos $total seleccionados';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '$count recursos multimedia detectados';
  }

  @override
  String get catcatchFlowSelectOrCombine =>
      '(seleccione un recurso o combine un par de audio/vídeo)';

  @override
  String get catcatchSelectMultiple =>
      '(toque para seleccionar; se permiten múltiples)';

  @override
  String get catcatchWaitingForResources => 'Esperando recursos de flujo';

  @override
  String catcatchDownloadSelected(Object count) {
    return 'Descargar recursos seleccionados $count';
  }

  @override
  String get catcatchSelectResources => 'Seleccionar recursos para descargar';

  @override
  String get catcatchPossibleSplit =>
      '⚠ Posibles transmisiones de audio y video separadas';

  @override
  String get catcatchSplitExplanation =>
      'Estos recursos pueden ser transmisiones de audio y video separadas para el mismo video. Puedes combinarlos o descargar solo una transmisión.';

  @override
  String get catcatchAudioStream => '🎵 Transmisión de audio';

  @override
  String get catcatchVideoStream => '🎬 Transmisión de vídeo';

  @override
  String get catcatchMergeAudioVideo => 'Combina audio y vídeo';

  @override
  String get catcatchVideoOnly => 'Sólo vídeo';

  @override
  String get catcatchAudioOnly => 'Sólo audio';

  @override
  String get catcatchSegmentsPlaylistPreview =>
      'Vista previa de segmentos usando la lista de reproducción';

  @override
  String get catcatchPreviewAudio => 'Vista previa de audio';

  @override
  String get catcatchPreviewVideo => 'Vista previa de vídeo';

  @override
  String catcatchDuration(Object duration) {
    return 'Duración: $duration';
  }

  @override
  String get catcatchSegment => 'Segmento';

  @override
  String get catcatchPlaylist => 'Lista de reproducción';

  @override
  String get catcatchFullVideo => 'vídeo completo';

  @override
  String get catcatchSeparateTracks => 'Pistas separadas';

  @override
  String get catcatchPreviewPlaylistOnly =>
      'Vista previa usando la lista de reproducción';

  @override
  String get catcatchPreviewUnsupported => 'La vista previa no es compatible';

  @override
  String get catcatchUnknownFormat => 'Formato desconocido';

  @override
  String get catcatchNeedPlaylistProcessing =>
      'Se requiere procesamiento de lista de reproducción';

  @override
  String get catcatchSpecialFormatDetected => 'Formato especial detectado';

  @override
  String catcatchPlaylistInfo(Object format) {
    return 'Este recurso es una lista de reproducción ($format). Debe analizarse y descargarse todos los segmentos y combinarse en un vídeo reproducible.';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return 'El archivo descargado está en $format, no en MP4 estándar. El motor Dart remux incorporado puro lo convertirá a MP4 (TS/FLV/EV1 no requiere dependencias externas).';
  }

  @override
  String get catcatchContinueBeforeConfirm =>
      'Reanudar el flujo antes de confirmar el manejo del formato.';

  @override
  String get catcatchAutoProcess => 'Procesar automáticamente';

  @override
  String get catcatchKeepOriginalFormat => 'Mantener formato original';

  @override
  String get catcatchResumeSupported => 'Reanudar apoyado';

  @override
  String get catcatchResumeUnsupported =>
      'Este sitio no admite la reanudación.';

  @override
  String get catcatchPauseDownload => 'Pausar descarga';

  @override
  String get catcatchResumeDownload => 'Reanudar descarga';

  @override
  String get catcatchRestartDownload => 'Descargar de nuevo';

  @override
  String get catcatchPendingFormatAction => 'Esperando recursos de flujo';

  @override
  String get quitDialogTitle => '¿Salir de la aplicación?';

  @override
  String quitDialogRunningTasks(Object count) {
    return 'Las tareas $count se están ejecutando. Dejar de fumar los interrumpirá. ¿Quieres dejarlo?';
  }

  @override
  String get quitDialogNoTasks => '¿Quieres dejar Stroom?';

  @override
  String get quitDialogCancel => 'Cancelar';

  @override
  String get quitDialogExit => 'Abandonar';

  @override
  String get searchPanelNewConversation => 'Nueva conversación';

  @override
  String get searchPanelTitle => 'Buscar conversaciones';

  @override
  String get searchPanelHint => 'Introduzca una palabra clave...';

  @override
  String get searchPanelByTitle => 'Buscar títulos';

  @override
  String get searchPanelByContent => 'Buscar contenido';

  @override
  String searchPanelResults(Object count) {
    return '$count resultados';
  }

  @override
  String get searchPanelPrompt => 'Ingrese una palabra clave para buscar';

  @override
  String get searchPanelNoResults =>
      'No se encontraron conversaciones coincidentes';

  @override
  String get topicItemNew => 'Nuevo tema';

  @override
  String get topicItemUnpin => 'Desprender';

  @override
  String get topicItemPin => 'Alfiler';

  @override
  String get topicItemRename => 'Rebautizar';

  @override
  String get topicItemAutoName => 'Nombre automático';

  @override
  String get topicItemDelete => 'Borrar';

  @override
  String get galleryChoiceTitle => 'Elige una fuente de imagen';

  @override
  String get galleryChoiceDevice => 'Galería de dispositivos';

  @override
  String get galleryChoiceDeviceDescription =>
      'Explora fotos y vídeos en tu dispositivo';

  @override
  String get galleryChoiceApp => 'galería de aplicaciones';

  @override
  String get galleryChoiceAppDescription =>
      'Elige de la galería de aplicaciones';

  @override
  String get appMediaUnreadable => 'No se pudo leer el archivo';

  @override
  String appMediaLoadError(Object error) {
    return 'No se pudieron cargar archivos: $error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return 'Borrar ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return 'Hecho ($count)';
  }

  @override
  String get appMediaConfirmSelection => 'Hecho';

  @override
  String get appMediaEmptyFolder => 'Esta carpeta está vacía';

  @override
  String get appMediaRoot => 'Ir a la carpeta raíz';

  @override
  String appMediaParentFolder(Object name) {
    return 'Atrás: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return 'Archivos $count seleccionados';
  }

  @override
  String get chatAlbumPickerTitle => 'Álbum de aplicaciones';

  @override
  String get chatAlbumPickerEmpty => 'No hay imágenes disponibles';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imágenes seleccionadas',
      one: '$count imagen seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => 'Elige archivos';

  @override
  String get chatFilePickerTabText => 'Texto';

  @override
  String get chatFilePickerTabImages => 'Imágenes';

  @override
  String get chatFilePickerTabVideos => 'Vídeos';

  @override
  String get chatFilePickerTabAudio => 'Audio';

  @override
  String get chatFilePickerEmpty => 'No hay archivos disponibles';

  @override
  String get chatFilePickerLoadFailed => 'No se pudieron cargar archivos';

  @override
  String get chatVideoPickerTitle => 'Elige vídeos de la aplicación';

  @override
  String get chatVideoPickerEmpty => 'No hay vídeos disponibles';

  @override
  String get imagePreviewCrop => 'Cultivo';

  @override
  String get imagePreviewEdit => 'Editar';

  @override
  String get imagePreviewLoadFailed => 'No se pudo cargar la imagen';

  @override
  String runningElapsed(Object elapsed) {
    return 'Corriendo para $elapsed';
  }

  @override
  String get chatAttachmentFile => 'Adjuntar archivo';

  @override
  String get chatAttachmentCamera => 'tomar foto';

  @override
  String get chatAttachmentDeviceGallery => 'Galería de dispositivos';

  @override
  String get chatAttachmentDeviceFiles => 'Archivos de dispositivo';

  @override
  String get chatAttachmentAppFiles => 'Archivos de aplicación';

  @override
  String fileManagerTodayTime(Object time) {
    return 'Hoy $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return 'Ayer $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return 'Hace $days días $time';
  }

  @override
  String get markdownGenerating => 'Generando...';

  @override
  String get htmlPreview => 'Avance';

  @override
  String get htmlReturnToCard => 'volver a la tarjeta';

  @override
  String get htmlGenerating => 'Generando...';

  @override
  String get htmlFullscreen => 'Ver pantalla completa';

  @override
  String get htmlViewCode => 'Ver código';

  @override
  String get codeScrollToBottom => 'Desplazarse hacia abajo';

  @override
  String get codeSave => 'Guardar';

  @override
  String get codeDisableWrap => 'Desactivar envoltura';

  @override
  String get codeEnableWrap => 'Líneas envolventes';

  @override
  String codeCopyFailed(Object error) {
    return 'Copia fallida: $error';
  }

  @override
  String get codeCopied => 'Copiado';

  @override
  String get codeCopy => 'Copiar';

  @override
  String get codeEmptySave => 'El código está vacío y no se puede guardar.';

  @override
  String get codeSaveTitle => 'Guardar código';

  @override
  String codeSavedTo(Object path) {
    return 'Guardado en: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return 'Error al guardar: $error';
  }

  @override
  String get fileManagerCopy => 'Copiar';

  @override
  String get fileManagerMove => 'Mover';

  @override
  String get fileManagerRename => 'Rebautizar';

  @override
  String get fileManagerExport => 'Exportar';

  @override
  String get fileManagerDelete => 'Borrar';

  @override
  String get fileManagerAncestorFolders => 'Carpetas de antepasados';

  @override
  String get fileManagerRoot => 'Raíz';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$count seleccionado';
  }

  @override
  String get fileManagerSelectAll => 'Seleccionar todo';

  @override
  String get fileManagerRenameUndo =>
      'Resultado de cambio de nombre del último lote y deshacer';

  @override
  String fileManagerSortBy(Object field) {
    return 'Ordenar ($field)';
  }

  @override
  String get fileManagerSortCreated => 'Ordenar por fecha de creación';

  @override
  String get fileManagerSortModified => 'Ordenar por fecha de modificación';

  @override
  String get fileManagerSortName => 'Ordenar por nombre';

  @override
  String get fileManagerSortSize => 'Ordenar por tamaño';

  @override
  String get fileManagerListView => 'Vista de lista';

  @override
  String get fileManagerThumbnailView => 'Vista en miniatura';

  @override
  String get fileManagerCreateFolder => 'Crear carpeta';

  @override
  String get fileManagerRefresh => 'Actualizar lista';

  @override
  String get fileManagerEmptyFolder => 'Esta carpeta está vacía';

  @override
  String get fileManagerNoFiles => 'Sin archivos';

  @override
  String get fileManagerBackRoot => 'Volver a la raíz';

  @override
  String fileManagerBackFolder(Object name) {
    return 'Atrás: $name';
  }

  @override
  String get fileManagerMultiSelect => 'Seleccionar múltiples';

  @override
  String get fileManagerOpen => 'Abierto';

  @override
  String get fileManagerPreview => 'Avance';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return 'Archivos $files, subcarpetas $folders';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return 'Subcarpetas $count';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return 'Archivos $count';
  }

  @override
  String get fileManagerEmptyFolderLabel => 'carpeta vacia';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return 'El archivo “$name.$format” ya existe';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return 'Error al cambiar el nombre: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => 'Elija una carpeta de destino';

  @override
  String get fileManagerAlreadyAtDestination =>
      'El archivo ya está en el destino.';

  @override
  String get fileManagerMoveNameConflict =>
      'Ya existe un archivo con el mismo nombre en el destino. Movimiento cancelado.';

  @override
  String fileManagerMoveFailed(Object error) {
    return 'Error al mover: $error';
  }

  @override
  String get fileManagerChooseCopyDestination =>
      'Elija una carpeta para copiar';

  @override
  String fileManagerCopyFailed(Object error) {
    return 'Copia fallida: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => 'Confirmar eliminación';

  @override
  String get fileManagerDeleteFileConfirm =>
      '¿Eliminar este archivo? Esta acción no se puede deshacer.';

  @override
  String get fileManagerCancel => 'Cancelar';

  @override
  String fileManagerDeleteFailed(Object error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere =>
      'La carpeta ya está en el destino. Operación cancelada.';

  @override
  String get fileManagerFolderConflict =>
      'Existe una carpeta con el mismo nombre en el destino o el destino está dentro de la carpeta seleccionada. Operación cancelada.';

  @override
  String get fileManagerBatchDeleteTitle => 'Confirmar eliminación masiva';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '¿Eliminar los elementos seleccionados $count? Esta acción no se puede deshacer.';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return 'Error en la eliminación masiva: $error';
  }

  @override
  String get fileManagerExportConflict =>
      'Las rutas de exportación para los archivos y carpetas seleccionados entran en conflicto';

  @override
  String get fileManagerSelectedAlreadyThere =>
      'El archivo seleccionado ya está en el destino. Movimiento cancelado.';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return 'Error en el movimiento masivo: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      'La selección contiene archivos con nombres duplicados. Copia cancelada; cópielos uno a la vez.';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return 'Error en la copia masiva: $error';
  }

  @override
  String get fileManagerClosedError => 'La página del archivo está cerrada.';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return 'Error al cambiar el nombre en masa: $error';
  }

  @override
  String get fileManagerFolderNameHint => 'Introduzca un nombre de carpeta';

  @override
  String get fileManagerCreate => 'Crear';

  @override
  String get fileManagerFolderExists => 'La carpeta ya existe';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return 'No se pudo crear la carpeta: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return 'Carpeta “$name” creada';
  }

  @override
  String get fileManagerRenameFolderTitle => 'Cambiar nombre de carpeta';

  @override
  String get fileManagerNewNameHint => 'Introduzca un nuevo nombre';

  @override
  String get fileManagerTargetFolderConflict =>
      'Ya existe una carpeta con el mismo nombre en el destino. Operación cancelada.';

  @override
  String get fileManagerMoveFolderTitle => 'Mover carpeta a…';

  @override
  String get fileManagerCopyFolderTitle => 'Copiar carpeta a…';

  @override
  String get fileManagerFolderSelfConflict =>
      'Existe una carpeta con el mismo nombre en el destino o el destino es la carpeta misma. Operación cancelada.';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return '¿Eliminar la carpeta “$name”? También se eliminarán sus archivos $count.';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '¿Eliminar la carpeta vacía “$name”?';
  }

  @override
  String get fileManagerDeleteFolderTitle => 'Confirmar eliminación de carpeta';

  @override
  String fileManagerRefreshFailed(Object error) {
    return 'Error al actualizar: $error';
  }

  @override
  String get fileManagerRefreshed => 'Lista de archivos actualizada';

  @override
  String get fileManagerRenameFileTitle => 'Cambiar nombre de archivo';

  @override
  String get fileManagerFormat => 'Formato';

  @override
  String get fileManagerFolderAtDestination =>
      'La carpeta ya está en el destino.';

  @override
  String get folderPickerTitle => 'Elige carpeta';

  @override
  String get folderPickerExists => 'La carpeta ya existe';

  @override
  String folderPickerCreateFailed(Object error) {
    return 'No se pudo crear la carpeta: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return 'No se pudo actualizar la lista de carpetas: $error';
  }

  @override
  String get folderPickerInstruction =>
      'Haga clic para seleccionar; haga doble clic para abrir una carpeta';

  @override
  String get folderPickerFileName => 'Nombre del archivo';

  @override
  String get folderPickerFileNameHint => 'Introduzca un nombre de archivo';

  @override
  String get folderPickerBack => 'Sube un nivel';

  @override
  String folderPickerPath(Object path) {
    return 'Raíz > $path';
  }

  @override
  String get folderPickerRoot => 'Raíz';

  @override
  String get folderPickerCurrentFolder => 'Carpeta actual';

  @override
  String get folderPickerSubfolders => 'Subcarpetas';

  @override
  String get folderPickerExistingFolders => 'Carpetas existentes';

  @override
  String get folderPickerCreateNew => 'Crear nueva carpeta';

  @override
  String get folderPickerFolderNameHint => 'Introduzca un nombre de carpeta';

  @override
  String get folderPickerCancelCreate => 'Cancelar creación';

  @override
  String get folderPickerCancel => 'Cancelar';

  @override
  String get folderPickerConfirm => 'Hecho';

  @override
  String batchRunReadFailed(Object error) {
    return 'No se pudo leer la lista de archivos: $error';
  }

  @override
  String get batchRunPreparing => 'Preparante…';

  @override
  String get batchRunUndo => 'Deshacer';

  @override
  String get batchRunRename => 'Rebautizar';

  @override
  String batchRunFailedAction(Object label) {
    return 'No se pudo $label';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label $count artículos';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed tuvo éxito, $failed falló, $remaining restante';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return 'Error: $id → $name';
  }

  @override
  String get batchRunReportCopied => 'Informe de ejecución copiado';

  @override
  String get batchRunCopyFailed => 'La copia falló. Intentar otra vez.';

  @override
  String batchRunWorking(Object label) {
    return '$label…';
  }

  @override
  String get batchRunTitle => 'Resultados de cambio de nombre por lotes';

  @override
  String get batchRunStoppedRetain =>
      'Al detenerse se mantienen los elementos completados. Puede deshacerlos en la página de resultados.';

  @override
  String get batchRunFailedRemaining =>
      'Fallido; Los elementos restantes no fueron procesados.';

  @override
  String get batchRunUndoInfo =>
      'Deshacer restaura los nombres originales de los elementos completados en esta ejecución. Se rechaza deshacer si la lista de archivos ha cambiado desde entonces.';

  @override
  String get batchRunUncertain =>
      'Algunos estados de los artículos no se pudieron confirmar. Verifique la lista de archivos; La función de deshacer automáticamente no está disponible para evitar sobrescribir archivos.';

  @override
  String get batchRunUndoing => 'Restaurando nombres originales...';

  @override
  String get batchRunStopping => 'Parada…';

  @override
  String get batchRunStopRemaining => 'Detener los elementos restantes';

  @override
  String get batchRunCopyReport => 'Copiar informe';

  @override
  String batchRunUndoRemaining(Object count) {
    return 'Continúe deshaciendo el $count restante';
  }

  @override
  String get batchRunUndoCompleted => 'Deshacer cambios de nombre completados';

  @override
  String get batchRunDone => 'Hecho';

  @override
  String get codeEditorTitle => 'Editar valor de parámetro';

  @override
  String get codeEditorFormat => 'Formato';

  @override
  String get codeEditorCancel => 'Cancelar';

  @override
  String get codeEditorConfirm => 'DE ACUERDO';

  @override
  String get codeEditorInvalidJson =>
      'JSON no válido. Arréglalo antes de guardar.';

  @override
  String get codeEditorParamPath =>
      'Ruta del nombre del parámetro (ampliada a JSON anidado cuando se envía)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return 'Línea $line, columna $column: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'Error de formato JSON: $message';
  }

  @override
  String get codeEditorInvalidFormat => 'Formato JSON no válido';

  @override
  String get toolCallCompacted => 'Comprimido';

  @override
  String get mermaidSaveEmpty =>
      'El código de sirena está vacío. Nada que salvar.';

  @override
  String mermaidFolderLoadFailed(String error) {
    return 'No se pudieron cargar carpetas: $error';
  }

  @override
  String get mermaidSaveTitle => 'Guardar diagrama de sirena';

  @override
  String get mermaidSaveHint => 'Elija o cree una carpeta para el archivo .mmd';

  @override
  String get mermaidSaveFilenameHint =>
      'Ingrese un nombre de archivo (.mmd se agrega automáticamente)';

  @override
  String get mermaidFilenameEmpty =>
      'El nombre del archivo no puede estar vacío';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return 'Guardado en almacenamiento de texto: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get mermaidPrepareEngine => 'Preparando motor de renderizado...';

  @override
  String get mermaidRetry => 'Rever';

  @override
  String get batchRuleEmpty => 'no puede estar vacio';

  @override
  String get batchRuleNumber => 'Introduce un número';

  @override
  String get batchRulePositive => 'Introduzca un número mayor que 0';

  @override
  String batchRuleMin(String min) {
    return 'Debe ser al menos $min';
  }

  @override
  String batchRuleMax(String max) {
    return 'No debe ser mayor que $max';
  }

  @override
  String get batchRulePrefix => 'Prefijo';

  @override
  String get batchRuleSuffix => 'Sufijo';

  @override
  String get batchRuleStart => 'Comenzar';

  @override
  String get batchRuleStep => 'Paso';

  @override
  String get batchRuleDigits => 'Dígitos';

  @override
  String get batchRuleSeparator => 'Separador';

  @override
  String get batchRuleRestartFolder =>
      'Reiniciar la numeración en cada carpeta.';

  @override
  String get batchRuleNumberHelp =>
      'Los números siguen el orden de vista previa; Los elementos excluidos no utilizan un número. El paso puede ser negativo o 0.';

  @override
  String get batchRuleFind => 'Encontrar';

  @override
  String get batchRuleReplace => 'Reemplazar con (dejar vacío para eliminar)';

  @override
  String get batchRuleCaseSensitive => 'Distingue mayúsculas y minúsculas';

  @override
  String get batchRuleRegex => 'expresión regular';

  @override
  String get batchRuleFirstOnly => 'Reemplazar solo la primera coincidencia';

  @override
  String get batchRuleRegexHelp =>
      'Grupos de captura: \$1, \$2; partido completo: \$0; literal \$: \$\$. Ejemplo: ^IMG_(\\d+)\$ → Foto_\$1';

  @override
  String get batchRuleFindRequired =>
      'Ingrese el texto que desea buscar para habilitar esta regla.';

  @override
  String get batchRuleBeginning => 'Comienzo';

  @override
  String get batchRuleEnd => 'Fin';

  @override
  String get batchRulePosition => 'Posición';

  @override
  String get batchRuleInsertText => 'Texto para insertar';

  @override
  String get batchRuleBeforeChar => 'Antes del personaje N';

  @override
  String get batchRulePositionHelp =>
      'Las posiciones comienzan en 1; se añaden los valores más allá del final. Los emoji combinados cuentan como un carácter.';

  @override
  String get batchRuleFromBeginning => 'Desde el principio';

  @override
  String get batchRuleFromEnd => 'desde el final';

  @override
  String get batchRuleFromChar => 'Comenzando en el carácter N';

  @override
  String get batchRuleCount => 'Contar';

  @override
  String get batchRuleDeleteHelp =>
      'Si la eliminación vacía el nombre, una regla de inserción posterior debe agregar texto antes de la ejecución.';

  @override
  String get batchRuleUpper => 'MAYÚSCULAS';

  @override
  String get batchRuleLower => 'minúscula';

  @override
  String get batchRuleFirstUpper => 'Poner en mayúscula la primera letra';

  @override
  String get batchRuleTitleCase => 'Ponga en mayúscula cada palabra';

  @override
  String get batchRuleTemplate => 'Nueva plantilla de nombre';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return 'Curso_${n}_$name';
  }

  @override
  String batchRuleTemplateHelp(
    String name,
    String n,
    String folder,
    String created,
    String modified,
    String ext,
  ) {
    return 'Nombre original $name · Secuencia $n · Nombre de carpeta $folder\n$created fecha de creación · $modified fecha de modificación · $ext extensión original\nFormato de fecha AAAA-MM-DD; Se informan las fechas faltantes. La plantilla reemplaza el nombre base completo; la extensión se mantiene automáticamente.';
  }

  @override
  String get batchRuleTrim => 'Recortar espacios iniciales y finales';

  @override
  String get batchRuleCollapseSpaces =>
      'Reemplazar espacios consecutivos con un espacio';

  @override
  String get batchRuleActions => 'Acciones de reglas';

  @override
  String get batchRuleDuplicate => 'Regla duplicada';

  @override
  String get batchRuleRemove => 'Eliminar regla';

  @override
  String get batchRuleMoveUp => 'Mover regla hacia arriba';

  @override
  String get batchRuleMoveDown => 'Mover regla hacia abajo';

  @override
  String get batchDlgSavePreset => 'Guardar preestablecido';

  @override
  String get batchDlgPresetName => 'Nombre preestablecido';

  @override
  String get batchDlgPresetHint =>
      'Guarda reglas y orden, pero no exclusiones ni nombres manuales.';

  @override
  String get batchDlgCancel => 'Cancelar';

  @override
  String get batchDlgSave => 'Guardar';

  @override
  String get batchDlgOverwriteTitle =>
      '¿Sobrescribir el ajuste preestablecido existente?';

  @override
  String batchDlgOverwriteBody(String name) {
    return 'Actualice las reglas en “$name”.';
  }

  @override
  String get batchDlgOverwrite => 'Exagerar';

  @override
  String get batchDlgManagePresets => 'Administrar ajustes preestablecidos';

  @override
  String get batchDlgNoPresets => 'No hay ajustes preestablecidos guardados';

  @override
  String get batchDlgDeletePreset => 'Eliminar preajuste';

  @override
  String get batchDlgDone => 'Hecho';

  @override
  String get batchDlgEditName => 'Editar nombre individualmente';

  @override
  String get batchDlgBaseName => 'Nombre básico';

  @override
  String get batchDlgOverrideHelp =>
      'Este nombre anula el resultado de la regla.';

  @override
  String batchDlgExtensionRetained(String extension) {
    return 'La extensión .$extension se mantiene automáticamente';
  }

  @override
  String get batchDlgConfirm => 'Confirmar';

  @override
  String get batchDlgHelp => 'Instrucciones';

  @override
  String get batchDlgClose => 'Cerrar';

  @override
  String get batchDlgLoadPreset =>
      'Cargar preset (reemplaza reglas y borra nombres manuales)';

  @override
  String get batchDlgLoad => 'Cargar preajuste';

  @override
  String get batchDlgSaving => 'Ahorro…';

  @override
  String get batchDlgReset =>
      'Restablecer todas las reglas y elementos incluidos';

  @override
  String get batchDlgRuleInstructions =>
      'Las reglas van de arriba a abajo. Cópielos, muévalos o deshabilítelos. Las extensiones de archivos permanecen sin cambios.';

  @override
  String get batchDlgSortName => 'Nombre';

  @override
  String get batchDlgSortCreated => 'Creado';

  @override
  String get batchDlgSortModified => 'Modificado';

  @override
  String get batchDlgSortSize => 'Tamaño';

  @override
  String get batchDlgAscending => 'Ascendente';

  @override
  String get batchDlgDescending => 'Descendente';

  @override
  String get batchDlgFolderSort =>
      'Las carpetas son lo primero; Los mismos nombres están ordenados por carpeta.';

  @override
  String get batchDlgAddRule => '＋ Agregar regla';

  @override
  String get batchDlgMaxRules => 'Máximo 50 reglas';

  @override
  String get batchDlgPreviewWorking =>
      'Calculando la vista previa... Puedes seguir editando reglas o cancelar.';

  @override
  String get batchDlgSearch => 'Buscar nombre original, nombre nuevo o carpeta';

  @override
  String get batchDlgFilterAll => 'Todo';

  @override
  String get batchDlgFilterChanged => 'Cambió';

  @override
  String get batchDlgFilterErrors => 'Asuntos';

  @override
  String get batchDlgFilterUnchanged => 'Sin alterar';

  @override
  String get batchDlgFilterExcluded => 'excluido';

  @override
  String get batchDlgParticipants => 'Elija artículos incluidos';

  @override
  String get batchDlgIncludeAll => 'incluir todo';

  @override
  String get batchDlgOnlyFiles => 'Sólo archivos';

  @override
  String get batchDlgOnlyFolders => 'Solo carpetas';

  @override
  String get batchDlgExcludeAll => 'Excluir todo';

  @override
  String get batchDlgScope => 'Artículos incluidos';

  @override
  String get batchDlgCopyList => 'Copiar lista';

  @override
  String get batchDlgConflictBlock =>
      'Conflicto de nombre: ejecución de bloque';

  @override
  String get batchDlgConflictSuffix =>
      'Conflicto de nombres: agregar (2), (3)…';

  @override
  String get batchDlgNoMatches => 'Ningún artículo coincide con el filtro';

  @override
  String get batchDlgRoot => 'Raíz';

  @override
  String get batchDlgFile => 'Archivo';

  @override
  String get batchDlgFolder => 'Carpeta';

  @override
  String batchDlgTargetFolder(String folder) {
    return 'Carpeta de destino: $folder';
  }

  @override
  String get batchDlgEditNameTooltip => 'Editar nombre individualmente';

  @override
  String get batchDlgRestoreNameTooltip =>
      'Restaurar el nombre generado por la regla';

  @override
  String get batchDlgCopied => 'Lista de vista previa completa copiada (CSV)';

  @override
  String get batchDlgCopyFailed => 'La copia falló. Intentar otra vez.';

  @override
  String get batchDlgHelpTitle =>
      'Instrucciones para cambiar el nombre por lotes';

  @override
  String get batchDlgHelpDismiss => 'Entiendo';

  @override
  String get batchDlgRulesTab => 'Normas';

  @override
  String batchDlgPreviewTab(String count) {
    return 'Vista previa ($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return 'Cambiar el nombre de los elementos $count';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      'No se pudieron cargar los ajustes preestablecidos. Aún puedes editar y ejecutar reglas.';

  @override
  String get batchDlgPreviewFailed =>
      'No se pudo calcular la vista previa. Ajusta las reglas y vuelve a intentarlo.';

  @override
  String batchDlgSavedName(String name) {
    return 'Preajuste guardado: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get batchDlgPresetWriteFailed =>
      'No se pudo guardar el ajuste preestablecido.';

  @override
  String batchDlgDeleteFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get batchDlgSavePresetFallback => 'Guardar preestablecido';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return 'Vista previa · Cambios en $changes · Problemas con $conflicts · $excluded excluido';
  }

  @override
  String get batchDlgInvalidInput =>
      'Corregir entradas de reglas no válidas. La vista previa aún no los incluye.';

  @override
  String get batchDlgConflictError =>
      'Los conflictos o los nombres no válidos impiden la aplicación. Ajusta las reglas.';

  @override
  String get batchDlgManualNameStatus => 'Nombre manual';

  @override
  String get batchDlgPendingRename => 'Listo para cambiar el nombre';

  @override
  String get batchDlgCsvHeader =>
      'Ruta original,Nombre original,Ruta de destino,Estado';

  @override
  String get batchDlgHelpBody =>
      '1. Elija un ajuste preestablecido o habilite reglas, luego copie las reglas y ajuste su orden según sea necesario.\n\n2. La vista previa muestra los nombres que se utilizarán. La búsqueda y los filtros afectan solo la visualización. Desmarcar un elemento lo excluye y recalcula la numeración. Edite un nombre individualmente o restaure el resultado de la regla.\n\n3. Resuelva todos los problemas antes de ejecutar. Los sufijos automáticos manejan nombres duplicados sin sobrescribir archivos. Cambie el nombre de las carpetas que intercambian nombres en lotes separados.\n\n4. Puede detener elementos posteriores durante la ejecución; el elemento actual termina primero. La página de resultados muestra los cambios completados y le permite deshacerlos. Deshacer se bloquea si la lista ha cambiado desde la ejecución.\n\nEsto cambia únicamente los nombres y las rutas de las carpetas; El contenido y las extensiones del archivo permanecen sin cambios. Cambiar el nombre de una carpeta principal no impide que se cambie el nombre de los elementos secundarios marcados, y cambiar el nombre de un elemento principal mueve a sus elementos secundarios con él.';

  @override
  String batchDlgPreviewCount(String count) {
    return 'Vista previa ($count)';
  }

  @override
  String get batchBuiltinPhoto => 'Fotos: fecha y número';

  @override
  String get batchBuiltinCourse => 'Cursos: nombre y número consistentes';

  @override
  String get batchBuiltinDownloads => 'Descargas: limpiar espacios en blanco';

  @override
  String get taskListDetail => 'Detalles';

  @override
  String get taskListOwnershipChecking => 'Confirmar la propiedad de la tarea';

  @override
  String get taskListOwnershipFailed =>
      'No se pudo leer el registro de flujo de tareas; las acciones no están disponibles';

  @override
  String get taskListViewFlow => 'Ver flujo de tareas';

  @override
  String get taskListPause => 'Pausa';

  @override
  String get taskListClear => 'Borrar tarea';

  @override
  String get taskListResume => 'Reanudar';

  @override
  String get taskListRetry => 'Rever';

  @override
  String get taskListDismissError => 'Descartar error';

  @override
  String get taskListRemove => 'Eliminar de la lista';

  @override
  String get taskListSynthesisErrorTitle => 'Detalles del error de síntesis';

  @override
  String get taskListClose => 'Cerrar';

  @override
  String get taskListOriginalExchange => 'Solicitud y respuesta originales';

  @override
  String get taskListOriginalRequest => 'Cuerpo de la solicitud original:';

  @override
  String get taskListOriginalResponse => 'Cuerpo de respuesta original:';

  @override
  String get taskFlowIoTypeText => 'Texto';

  @override
  String get taskFlowIoTypeAudio => 'Audio';

  @override
  String get taskFlowIoTypeVideo => 'Video';

  @override
  String get taskFlowIoTypeImage => 'Imagen';

  @override
  String get taskFlowIoTypeLink => 'Enlace';

  @override
  String get taskFlowIoTypeFile => 'Archivo';

  @override
  String get taskFlowIoTypeAny => 'Cualquier';

  @override
  String get mermaidZoomOut => 'alejar';

  @override
  String get mermaidZoomIn => 'Dar un golpe de zoom';

  @override
  String get mermaidFullscreen => 'Pantalla completa';

  @override
  String get mermaidSaveButton => 'Guardar';

  @override
  String get mermaidSourceButton => 'Ver fuente';

  @override
  String get mermaidDiagramSemantic => 'Ver diagrama';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'No se pudo guardar el estado de eliminación de la tarea secundaria de CatCatch. Intentar otra vez.';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      'No se pudo guardar el estado de eliminación de la tarea secundaria de síntesis. Intentar otra vez.';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      'No se pudo guardar el estado de eliminación de la tarea secundaria en segundo plano. Intentar otra vez.';

  @override
  String get mathParseError => 'Error de análisis matemático';

  @override
  String get mermaidEmptyPlaceholder =>
      'No hay código de sirena para renderizar';

  @override
  String get mathClose => 'Cerrar';

  @override
  String get mermaidLoadTimeout =>
      'Se agotó el tiempo de carga de la sirena. Verifique su red e inténtelo nuevamente.';

  @override
  String get mermaidCdnLoadFailed =>
      'No se pudo acceder a cdn.jsdelivr.net para cargar Mermaid.';

  @override
  String get mermaidLoadingDiagram => 'Cargando diagrama…';

  @override
  String get mermaidEngineInitFailed =>
      'No se pudo inicializar el renderizador de diagramas. Intentar otra vez.';

  @override
  String get mermaidPageTimeout =>
      'Se agotó el tiempo de carga de la página. Intentar otra vez.';

  @override
  String get mermaidCodeLoadFailed =>
      'No se pudo cargar el código del diagrama. Intentar otra vez.';

  @override
  String mermaidPageLoadFailed(String description) {
    return 'Error al cargar la página: $description';
  }

  @override
  String get mermaidLoadingEngine => 'Cargando motor de renderizado…';

  @override
  String get mermaidRenderErrorTitle => 'Error de representación del diagrama';

  @override
  String get taskFlowOutputVideoAudioDownstream =>
      'Vídeo o audio (filtrado por downstream)';

  @override
  String get taskFlowOutputUnknown => 'Desconocido';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label se detuvo: $completed tuvo éxito, $failed falló, $remaining restante';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Error de renderizado de sirena: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Error de inicialización de sirena: $message';
  }

  @override
  String get mermaidResourceError =>
      'No se pudo cargar un recurso en el diagrama de Mermaid.';

  @override
  String get taskFlowParamRecognitionModel => 'Modelo de reconocimiento';

  @override
  String get taskFlowParamSynthesisModel => 'Modelo de síntesis';

  @override
  String get taskFlowParamSaveFolder => 'Guardar carpeta';

  @override
  String get taskFlowParamResourceSelection => 'Selección de recursos';

  @override
  String get taskFlowParamOutputType => 'Tipo de salida';

  @override
  String get taskFlowParamVideoFolder => 'Carpeta para guardar vídeos';

  @override
  String get taskFlowParamAudioFolder => 'Carpeta para guardar audio';

  @override
  String get taskFlowParamExpectedDuration => 'Duración esperada';

  @override
  String get taskFlowParamVoice => 'Voz';

  @override
  String get taskFlowParamSpeechRate => 'Velocidad del habla';

  @override
  String get taskFlowParamAssistant => 'Asistente';

  @override
  String get taskFlowHintResourceSelection =>
      'El modo manual te permite elegir. El modo automático sigue las reglas existentes. Preguntar cuando ambiguo selecciona automáticamente solo cuando hay una opción segura; de lo contrario, abre la lista de recursos para su confirmación.';

  @override
  String get taskFlowHintOutputType =>
      'Elija video o audio explícitamente. Siga los recursos de filtros posteriores según el tipo de entrada del siguiente bloque. Si el siguiente bloque acepta ambos tipos o no hay un siguiente bloque, se mantienen ambos tipos.';

  @override
  String get taskFlowHintExpectedDuration =>
      'Filtrar recursos por duración del video. Déjelo en blanco para omitir el filtrado.';

  @override
  String get taskFlowHintVoice =>
      'Elige una voz. El modelo de síntesis coincidente se selecciona automáticamente.';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      'Este tipo de bloque ya no es compatible. Reemplácelo o elimine este paso.';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return 'El siguiente bloque requiere $requiredType. El descargador puede generar video o audio. Cambie el siguiente paso o política de salida.';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source tiene cualquier tipo, pero “$block” necesita un tipo de texto, enlace, imagen, audio, video o archivo explícito. Cambie el tipo de entrada, mueva o reemplace el bloque, o deshaga el cambio.';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source tiene $actualType, pero “$block” requiere $requiredType. Cambie el tipo de entrada, mueva o reemplace el bloque, o deshaga el cambio.';
  }

  @override
  String get fileManagerSortFieldCreated => 'Fecha de creación';

  @override
  String get fileManagerSortFieldModified => 'Fecha de modificación';

  @override
  String get fileManagerSortFieldName => 'Nombre';

  @override
  String get fileManagerSortFieldSize => 'Tamaño';

  @override
  String get fileManagerSortDateNewest => 'lo nuevo primero';

  @override
  String get fileManagerSortDateOldest => 'el mayor primero';

  @override
  String get fileManagerSortSizeLargest => 'más grande primero';

  @override
  String get fileManagerSortSizeSmallest => 'el más pequeño primero';

  @override
  String get catcatchStatusRunning => 'Correr';

  @override
  String get catcatchStatusCompleted => 'Terminado';

  @override
  String get catcatchStatusFailed => 'Fallido';

  @override
  String get catcatchStatusPaused => 'En pausa';

  @override
  String get catcatchStatusWaiting => 'Espera';

  @override
  String get catcatchStepFetching => 'Obteniendo página web';

  @override
  String get catcatchStepAnalyzing => 'Analizando medios';

  @override
  String get catcatchStepParsingPlaylist => 'Analizando lista de reproducción';

  @override
  String get catcatchStepFiltering => 'Filtrar por duración';

  @override
  String get catcatchStepUserSelecting => 'Esperando la selección';

  @override
  String get catcatchStepDownloading => 'Descargando';

  @override
  String get catcatchStepConverting => 'Convertir/fusionar';

  @override
  String get catcatchStepSaving => 'Guardar localmente';

  @override
  String get bgStepConnectServer => 'Conexión al servidor';

  @override
  String get bgStepUploadImage => 'Subiendo imágenes';

  @override
  String get bgStepWaitRecognition => 'Esperando reconocimiento';

  @override
  String get bgStepParseResult => 'Resultado del análisis';

  @override
  String get bgStepSaveFile => 'Guardando archivo';

  @override
  String get bgStepUploadAudio => 'Subiendo audio';

  @override
  String get bgStepTranscribing => 'Transcribiendo';

  @override
  String get bgStepReceiveResult => 'Recibiendo resultado';

  @override
  String get bgStepSeparateAudio => 'Separando audio';

  @override
  String get bgStepSaveToFile => 'Guardar en archivo';

  @override
  String get bgStepSendRequest => 'Enviando solicitud';

  @override
  String get bgStepWaitReply => 'Esperando respuesta';

  @override
  String get fileManagerSortNameAscending => 'De la A a la Z';

  @override
  String get fileManagerSortNameDescending => 'Z a A';

  @override
  String get taskFlowValidationNoSteps =>
      'Este flujo de tareas no tiene pasos. Primero agrega un bloque.';

  @override
  String get taskFlowValidationInputRequired =>
      'Agregue al menos una entrada para ejecutar este flujo de tareas.';

  @override
  String get taskFlowValidationFlowRemoved =>
      'Este flujo de tareas fue eliminado. Selecciónelo nuevamente.';

  @override
  String get taskFlowValidationInputTypeChanged =>
      'El tipo de entrada inicial cambió. Elija la entrada de ejecución nuevamente.';

  @override
  String get taskFlowValidationSnapshotMissing =>
      'Este registro anterior no tiene una instantánea de ejecución. Vuelva a intentar utilizar la configuración más reciente.';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      'El modelo de asistente falta o no está disponible. Seleccione un modelo en la página de chat o establezca un modelo predeterminado para el asistente.';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      'Falta un archivo de pasos guardado, está vacío o es ilegible. Ejecute el flujo de tareas nuevamente.';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      'Este tipo de bloque ya no es compatible. Reemplace o elimine este paso.';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return 'El siguiente bloque requiere $requiredType. El descargador puede generar audio o video. Cambie el siguiente paso o política de salida.';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return 'Se requiere “$parameter” para “$block”. Configúrelo en la configuración del bloque.';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return 'La selección del modelo heredado necesita confirmación. Elija el modelo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return 'El modelo falta o no está disponible por parte de su proveedor. Elíjalo nuevamente en la configuración de “$block” y verifique la URL y la clave del proveedor.';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return 'El asistente falta o fue eliminado. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      'El modelo de asistente fue eliminado o su configuración de proveedor no está disponible. Elija un modelo nuevamente en la configuración del asistente.';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return 'La política de selección de recursos o el tipo de salida no son válidos. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return 'El tipo de salida no es válido. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return 'La política de selección de recursos no es válida. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return 'Entrada $index: El archivo falta, está vacío o es ilegible. Elígelo de nuevo.';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return 'Ingrese $index: Ingrese un enlace HTTP o HTTPS válido.';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return 'Entrada $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules =>
      'Se permiten como máximo 50 reglas.';

  @override
  String get batchRuleValidationDigits =>
      'El número de dígitos debe ser del 1 al 12.';

  @override
  String get batchRuleValidationNumberRange =>
      'El número inicial y el paso deben estar dentro de ±999.999.999.';

  @override
  String get batchRuleValidationReplacementLength =>
      'La norma de sustitución es demasiado larga.';

  @override
  String get batchRuleValidationRegex => 'La expresión regular no es válida.';

  @override
  String get batchRuleValidationDeleteIndex =>
      'La posición de eliminación debe comenzar en 1.';

  @override
  String get batchRuleValidationInsertLength =>
      'El texto insertado es demasiado largo.';

  @override
  String get batchRuleValidationTemplateNumber =>
      'Configuración de número de plantilla no válida: los dígitos deben ser del 1 al 12 y el inicio/paso dentro de ±999,999,999.';

  @override
  String get batchRuleValidationTemplateLength =>
      'La plantilla es demasiado larga.';

  @override
  String get batchRuleValidationTemplateVariable =>
      'Variable de plantilla desconocida o llave abierta.';

  @override
  String get batchRuleTypeNumber => 'Añadir numeración';

  @override
  String get batchRuleTypeReplace => 'Buscar y reemplazar';

  @override
  String get batchRuleTypeInsert => 'Insertar texto';

  @override
  String get batchRuleTypeDelete => 'Eliminar caracteres';

  @override
  String get batchRuleTypeCase => 'Cambiar caso';

  @override
  String get batchRuleTypeTemplate => 'Plantilla de nombre';

  @override
  String get batchRuleTypeCleanup => 'Limpiar espacios en blanco';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return 'Ingrese $index: ingrese texto o elija un archivo.';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return 'Entrada $index: La imagen tiene más de 20 MB. Elija una imagen más pequeña.';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return 'Entrada $index: El archivo adjunto tiene más de 10 MB. Elija un archivo más pequeño.';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return 'Ingrese $index: el archivo es $actualType, pero se requiere $requiredType. Elija otro archivo.';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return 'Entrada $index: El chat del asistente no admite archivos adjuntos de imágenes SVG. Conviértelo a PNG o JPEG.';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return 'Entrada $index: El chat del asistente no admite archivos adjuntos de imágenes $mime. Conviértelo a PNG, JPEG, GIF o WebP.';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return 'Entrada $index: El chat del asistente no admite archivos adjuntos de audio $mime. Conviértelo a MP3, WAV o M4A.';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return 'Ingrese $index: este formato de chat antrópico no admite archivos adjuntos $type. Elija un asistente que admita este medio.';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return 'Ingrese $index: este formato de chat antrópico solo admite archivos adjuntos de imágenes y PDF. Elija un archivo compatible.';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return 'Ingrese $index: El chat del asistente no pudo comprimir la imagen por debajo de 10 MB. Elija una imagen más pequeña.';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return 'Entrada $index: El texto adjunto no es UTF-8 válido. Conviértelo e inténtalo de nuevo.';
  }

  @override
  String get assistantParamValueTypeString => 'Cadena';

  @override
  String get assistantParamValueTypeNumber => 'Número';

  @override
  String get assistantParamValueTypeBoolean => 'Booleano';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields =>
      'Se requieren el nombre del proveedor, la URL de API y la clave.';

  @override
  String get providerJsonSizePositive =>
      'El tamaño JSON de la solicitud debe ser un valor MiB positivo.';

  @override
  String get providerCustomParamRequired =>
      'Se requieren el nombre y el valor del parámetro personalizado.';

  @override
  String providerParamNameInvalid(String name) {
    return 'El nombre del parámetro no es válido (los segmentos separados por puntos no pueden estar vacíos): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return 'El parámetro ya existe: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return 'El valor predeterminado para el parámetro \"$name\" no es válido JSON: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return 'Las opciones numéricas para el parámetro \"$name\" no pueden estar vacías.';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return 'El valor del parámetro \"$name\" no es un número válido: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      'Complete la alternancia de razonamiento antes de habilitar otros parámetros de razonamiento.';

  @override
  String providerReasoningError(String error) {
    return 'Error de parámetro de razonamiento: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return 'Los parámetros de razonamiento y personalizados tienen el mismo nombre: $name';
  }

  @override
  String get providerMaxTokensMissing =>
      'Los tokens de salida máximos están habilitados, pero no se ingresó ningún valor.';

  @override
  String get providerMaxTokensPositive =>
      'Los tokens de salida máximos deben ser un número entero positivo.';

  @override
  String get providerSeedInteger =>
      'La semilla aleatoria debe ser un número entero.';

  @override
  String get providerNotConfigured => 'No establecido';

  @override
  String get providerAudioChunkingTitle => 'fragmentación de audio';

  @override
  String get providerAudioChunkingHint =>
      'La fragmentación inteligente analiza el audio y los cortes candidatos, prefiriendo las terminaciones de oraciones. Los trozos no se superponen.';

  @override
  String get providerChunkingMode => 'método de fragmentación';

  @override
  String get providerChunkNone => 'sin fragmentación';

  @override
  String get providerChunkSmart => 'Fragmentación inteligente (recomendado)';

  @override
  String get providerChunkFixedDuration => 'Fragmentos de duración fija';

  @override
  String get providerChunkFixedSize => 'Trozos de tamaño fijo';

  @override
  String get providerCompressionTitle => 'Codificación de compresión';

  @override
  String get providerCompressionHint =>
      'Cuando está habilitado, el respaldo general primero comprime el WAV completo. Si el archivo codificado o el cuerpo de la solicitud aún supera el límite, el PCM de origen se fragmenta y codifica.';

  @override
  String get providerCompressionMode => 'Método de compresión';

  @override
  String get providerCompressionNone => 'Ninguno (enviar tal cual)';

  @override
  String get providerCompressionAdpcm => 'ADPCM (~4x compresión)';

  @override
  String get providerCompressionFlac => 'FLAC (sin pérdidas, ~2x)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM, compresión 4:1 con pérdida. Implementación de Pure Dart; La calidad del audio se adapta a la transcripción.';

  @override
  String get providerCompressionFlacDescription =>
      'Compresión FLAC sin pérdidas, implementada en Dart puro. Reduce el tamaño aproximadamente a la mitad.';

  @override
  String get providerCompressionWavDescription =>
      'Sin compresión; enviar como un archivo WAV.';

  @override
  String get providerLlmParams => 'Parámetros del LLM';

  @override
  String get providerEnabledParamsHelp =>
      'Los parámetros habilitados se envían de forma predeterminada en las solicitudes de API.';

  @override
  String get providerTemperatureLabel => 'Temperatura';

  @override
  String get providerTemperatureHelp =>
      'Controla la aleatoriedad de la salida; Los valores más altos son más creativos.';

  @override
  String get providerTopPHelp =>
      'Parámetro de muestreo de núcleo que controla la probabilidad acumulada para la selección de palabras.';

  @override
  String get providerFrequencyPenaltyLabel => 'Penalización de frecuencia';

  @override
  String get providerFrequencyPenaltyHelp =>
      'Reduce las palabras repetidas; los valores negativos aumentan la repetición.';

  @override
  String get providerPresencePenaltyLabel => 'Penalización de presencia';

  @override
  String get providerPresencePenaltyHelp =>
      'Fomenta nuevos temas; los valores negativos alientan a volver a temas anteriores.';

  @override
  String get providerMaxOutputTokensLabel => 'Tokens de salida máximos';

  @override
  String providerOptionalExample(String example) {
    return 'Opcional, p.e. $example';
  }

  @override
  String get providerResponseTokensHelp =>
      'Número máximo de tokens generados por respuesta.';

  @override
  String get providerSeedLabel => 'semilla aleatoria';

  @override
  String get providerSeedHelp =>
      'Configúrelo para que la salida sea reproducible.';

  @override
  String get providerChunkSmartDescription =>
      'Analiza cortes de audio y candidatos, prefiriendo finales de oración o silencios largos sin superposición. Valores predeterminados: 20 s mínimo / 45 s objetivo / 60 s máximo. Utilizado sólo por el respaldo general; La fragmentación de compresión solo admite PCM WAV.';

  @override
  String get providerChunkDurationDescription =>
      'Se divide cada N segundos (60 por defecto). Simple, pero puede cortar el habla. Utilizado sólo por el respaldo general; La fragmentación de compresión solo admite PCM WAV.';

  @override
  String get providerChunkSizeDescription =>
      'Inicialmente se divide por tamaño de datos de audio, luego se refina por archivo codificado y tamaño del cuerpo de la solicitud. Utilizado sólo por el respaldo general; La fragmentación de compresión solo admite PCM WAV.';

  @override
  String get providerChunkNoneDescription =>
      'Sin fragmentación. El archivo se rechaza si excede el límite después de la compresión completa.';

  @override
  String get providerNameLabel => 'Nombre del proveedor';

  @override
  String get providerNameHint => 'Introduzca el nombre del proveedor';

  @override
  String get providerApiUrlLabel => 'URL de la API';

  @override
  String get providerApiUrlHint =>
      'Ingrese la URL completa del punto final de la API';

  @override
  String providerApiKeyHint(String hint) {
    return 'Pista: $hint';
  }

  @override
  String get providerEndpointTypeLabel => 'Tipo de punto final';

  @override
  String get providerEndpointOpenAi =>
      'Compatible con OpenAI (finalizaciones de chat)';

  @override
  String get providerEndpointAnthropic => 'Formato antrópico (API de mensajes)';

  @override
  String get providerAnthropicEndpointHelp =>
      'Utiliza el formato API oficial de Anthropic Messages (encabezado x-api-key). Ejemplo de URL de API: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      'Utiliza el formato oficial compatible con OpenAI Chat Completions (encabezado de portador). Ejemplo de URL de API: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault =>
      'Tamaño JSON de solicitud predeterminado';

  @override
  String get providerUseAppDefault =>
      'Déjelo vacío para usar la aplicación predeterminada';

  @override
  String get providerModelJsonBudgetHelp =>
      'Los modelos pueden anular este valor. Si ni el proveedor ni el modelo lo configuran, el valor predeterminado es 20 MiB.';

  @override
  String get providerRequestParamsHelp =>
      'Las solicitudes utilizan todos los parámetros de modelo y proveedor habilitados. Cuando los nombres se superponen, el valor del modelo tiene prioridad.';

  @override
  String get providerUploadSettings => 'Cargar configuración';

  @override
  String get providerUploadMethodHelp =>
      'Los métodos de carga de audio y los límites de tamaño varían según el proveedor.';

  @override
  String get providerUploadMethod => 'Método de carga';

  @override
  String get providerMultipart => 'Multiparte (general)';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => 'Tamaño máximo de carga';

  @override
  String get providerFallbackStrategy => 'estrategia alternativa';

  @override
  String get providerFallbackMethod => 'Método alternativo';

  @override
  String get providerPreprocessing => 'Preprocesamiento de audio';

  @override
  String get providerPreprocessingHelp =>
      'Reduce el tamaño del archivo de audio sin afectar la precisión de la transcripción.';

  @override
  String get providerPreprocessingMethod => 'Método de preprocesamiento';

  @override
  String get providerUploadMultipartHelp =>
      'Carga directa de datos de formulario/multiparte. El cuerpo de la solicitud incluye audio, campos de formulario y límites de varias partes.';

  @override
  String get providerUploadBase64Help =>
      'Envía Base64 en JSON, lo que puede eludir los límites específicos de varias partes de algunos proveedores. La expansión Base64 y los campos JSON cuentan para el límite de carga.';

  @override
  String get providerUploadUrlHelp =>
      'Proporcione una URL pública para que el proveedor la descargue. Admite archivos muy grandes (por ejemplo, Together AI 1 GB).';

  @override
  String get providerUploadBudgetHelp =>
      'Este valor desencadena una reserva de audio sin formato y limita el cuerpo de la solicitud final. La aplicación verifica el audio sin procesar, los archivos codificados y el tamaño de carga. Multiparte incluye campos y límites de formulario; Base64 JSON incluye campos y expansión de codificación. El valor predeterminado de 25 MB coincide con el límite de la API de audio de OpenAI.';

  @override
  String get providerFallbackTriggerHelp =>
      'Se activa cuando el audio sin procesar o el cuerpo completo de la solicitud excede su límite. El respaldo específico (Base64) tiene prioridad sobre el respaldo general (compresión/fragmentación).';

  @override
  String get providerFallbackNone => 'Ninguno (rechazar inmediatamente)';

  @override
  String get providerFallbackSpecific => 'Respaldo específico (Base64)';

  @override
  String get providerFallbackGeneric =>
      'Respaldo general (compresión/fragmentación)';

  @override
  String get providerFallbackAll => 'Pruebe todo (recomendado)';

  @override
  String get providerFallbackSpecificHelp =>
      'Pruebe Base64 JSON. Envíe solo si el cuerpo de la solicitud, incluida la expansión Base64 y los campos JSON, se ajusta al límite.';

  @override
  String get providerFallbackGenericHelp =>
      'Si está habilitado, comprima primero el WAV completo. Si aún excede el límite y la fragmentación está habilitada, divida el PCM de origen y codifique cada fragmento. Sólo PCM WAV.';

  @override
  String get providerFallbackAllHelp =>
      'Pruebe primero Base64 dentro del límite del cuerpo de la solicitud. Luego, si está habilitado, comprima el WAV completo; Si aún excede el límite y la fragmentación está habilitada, divida el PCM de origen y codifique cada fragmento. Sólo PCM WAV.';

  @override
  String get providerFallbackRejectHelp =>
      'Rechazar el archivo si excede el límite; no intente una alternativa.';

  @override
  String get providerPreprocessNone => 'Ninguno';

  @override
  String get providerPreprocessResample => 'Optimización WAV (mono de 16 kHz)';

  @override
  String get providerPreprocessResampleHelp =>
      'Remuestrea a 16 kHz y mezcla en mono. Reduce el tamaño entre 4 y 6 veces con poco efecto en la precisión de la transcripción.';

  @override
  String get providerPreprocessNoneHelp =>
      'Sin preprocesamiento; enviar tal cual.';

  @override
  String get assistantDefaultsScopeHelp =>
      'El modelo y las herramientas predeterminados se aplican solo a las nuevas conversaciones creadas con este asistente. Las conversaciones existentes mantienen su propia configuración. El truncamiento de salida de la herramienta se aplica a todas las conversaciones.';

  @override
  String get assistantDefaultModelTitle => 'Modelo predeterminado';

  @override
  String get assistantDefaultModelHelp =>
      'Modelo utilizado para nuevas conversaciones; déjelo sin configurar para dejar que la conversación elija.';

  @override
  String get assistantNoDefault => 'No establecido';

  @override
  String get assistantNoModelsAvailable =>
      'No hay modelos disponibles. Configure un proveedor de LLM en Configuración.';

  @override
  String get assistantDefaultToolsTitle =>
      'Herramientas habilitadas por defecto';

  @override
  String get assistantDisabledToolsHelp =>
      'Las herramientas deshabilitadas no se habilitarán automáticamente en nuevas conversaciones.';

  @override
  String get assistantUnconfiguredToolsHelp =>
      'Las herramientas predeterminadas no están configuradas. Las nuevas conversaciones habilitarán todas las herramientas automáticamente.';

  @override
  String get assistantEnableAll => 'Habilitar todo';

  @override
  String get assistantDisableAll => 'Desactivar todo';

  @override
  String get assistantNoToolsAvailable => 'No hay herramientas disponibles';

  @override
  String get assistantTruncateToolOutput =>
      'Truncamiento de salida de herramienta';

  @override
  String get assistantTruncateToolOutputHelp =>
      'Número máximo de caracteres en cada resultado de herramienta antes de enviarlo al modelo. Se aplica a todas las conversaciones bajo este asistente.';

  @override
  String get assistantEnableTruncation => 'Habilitar truncamiento';

  @override
  String assistantTruncatedTo(String count) {
    return 'Los resultados largos se truncan a caracteres $count';
  }

  @override
  String get assistantSendFullResult =>
      'Enviar resultado completo (sujeto al límite de almacenamiento de 50 KB)';

  @override
  String get assistantMaxCharacters => 'Caracteres máximos';

  @override
  String get assistantCharactersNotTokens => 'Unidad: personajes (no fichas)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return 'Valor predeterminado: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return 'Rango válido: caracteres $minimum–$maximum';
  }

  @override
  String get assistantNewConversationPreview =>
      'Vista previa de nueva conversación';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled / $total habilitado';
  }

  @override
  String get assistantAllToolsAutoEnabled =>
      'Todas las herramientas se habilitan automáticamente (no se configuran)';

  @override
  String get assistantMoreActions => 'Más acciones';

  @override
  String get assistantChooseEmoji => 'Elige emojis';

  @override
  String get assistantNameLabel => 'Nombre del asistente';

  @override
  String get assistantDescriptionOptional => 'Descripción (opcional)';

  @override
  String get assistantSelectionTitle => 'Elige un asistente';

  @override
  String get assistantMarketTooltip => 'Mercado asistente';

  @override
  String get assistantDefaultPrompt =>
      'Eres un útil asistente de IA. Responda las preguntas del usuario de forma clara y útil.';

  @override
  String get assistantCreateNew => 'Crear asistente';

  @override
  String get assistantEmptyState =>
      'Aún no hay asistentes. Crea uno para comenzar.';

  @override
  String get assistantCreate => 'Crear';

  @override
  String get assistantReorderHint =>
      'Mantenga presionado y arrastre para reordenar los asistentes';

  @override
  String get assistantNewNameHint => 'Introduzca el nombre del asistente';

  @override
  String get assistantNewDescriptionHint =>
      'Describe brevemente qué hace este asistente.';

  @override
  String get assistantDeleteTitle => 'Eliminar asistente';

  @override
  String assistantDeleteConfirmation(String name) {
    return '¿Eliminar asistente “$name”? Esta acción no se puede deshacer.';
  }

  @override
  String get assistantEditTitle => 'Asistente de edición';

  @override
  String get assistantBasicTab => 'Configuraciones básicas';

  @override
  String get assistantParametersTab => 'Parámetros';

  @override
  String get assistantDefaultsTab => 'Valores predeterminados';

  @override
  String get assistantAddCustomParameter => 'Agregar parámetro personalizado';

  @override
  String get assistantEditCustomParameter => 'Editar parámetro personalizado';

  @override
  String get assistantParameterName => 'Nombre del parámetro';

  @override
  String get assistantParameterNameHint => 'p.ej. top_k o proveedor.solo';

  @override
  String get assistantParameterNameInvalid =>
      'Nombre de parámetro no válido (los segmentos separados por puntos no pueden estar vacíos)';

  @override
  String get assistantParameterType => 'Tipo';

  @override
  String get assistantValue => 'Valor';

  @override
  String get assistantTrueFalseHint => 'verdadero o falso';

  @override
  String get assistantNumberHint => 'Introduce un número';

  @override
  String assistantJsonHint(String example) {
    return 'p.ej. $example';
  }

  @override
  String get assistantValueHint => 'Introduce un valor';

  @override
  String get assistantCancel => 'Cancelar';

  @override
  String get assistantSave => 'Guardar';

  @override
  String get assistantParamOverrideHelp =>
      'Cuando están habilitados, los parámetros del asistente anulan los parámetros del modelo; cuando está deshabilitado, se utilizan los parámetros del modelo.';

  @override
  String get assistantTemperature => 'Temperatura';

  @override
  String get assistantMaxTokens => 'Fichas máximas';

  @override
  String get assistantMaxToolCalls => 'Llamadas máximas a herramientas';

  @override
  String assistantRounds(String count) {
    return 'Rondas $count';
  }

  @override
  String get assistantUnlimited => 'Ilimitado';

  @override
  String get assistantStreamOutput => 'Salida de flujo';

  @override
  String get assistantFrequencyPenalty => 'Penalización de frecuencia';

  @override
  String get assistantPresencePenalty => 'Penalización de presencia';

  @override
  String get assistantRandomSeed => 'semilla aleatoria';

  @override
  String get assistantNotSet => 'No establecido';

  @override
  String get assistantSeedValue => 'Valor de la semilla';

  @override
  String get assistantIntegerSeedHint => 'Introduzca una semilla entera';

  @override
  String get assistantWebSearch => 'búsqueda web';

  @override
  String get assistantAddParameter => 'Agregar parámetro';

  @override
  String get assistantNoCustomParameters => 'Sin parámetros personalizados';

  @override
  String get assistantRoundsLabel => 'Rondas';

  @override
  String get modelCreateTitle => 'Agregar modelo';

  @override
  String get modelEditTitle => 'Editar modelo';

  @override
  String get modelDiscardTitle => '¿Descartar cambios?';

  @override
  String get modelDiscardBody => 'Tienes cambios sin guardar. ¿Descartarlos?';

  @override
  String get modelNameLabel => 'Nombre del modelo';

  @override
  String get modelNameHint => 'Ingrese un nombre para mostrar (opcional)';

  @override
  String get modelIdLabel => 'ID del modelo';

  @override
  String modelIdExample(String id) {
    return 'p.ej. $id';
  }

  @override
  String get modelIdRequired => 'Se requiere identificación del modelo.';

  @override
  String get modelCustomParamRequired =>
      'Se requieren el nombre del parámetro personalizado y el valor predeterminado.';

  @override
  String modelParamDuplicate(String name) {
    return 'El parámetro ya existe: $name';
  }

  @override
  String modelParamReserved(String name) {
    return 'Nombre del parámetro OCR reservado: $name';
  }

  @override
  String get modelParamName => 'Nombre del parámetro';

  @override
  String get modelParamDefaultValue => 'Valor de parámetro predeterminado';

  @override
  String get modelParamDelete => 'Eliminar parámetro';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return 'El valor predeterminado para el parámetro \"$name\" no es válido JSON: $value';
  }

  @override
  String get modelAddParameter => 'Agregar parámetro';

  @override
  String get modelNoCustomParams => 'Sin parámetros personalizados';

  @override
  String get modelBasicSettings => 'Configuraciones básicas';

  @override
  String get modelDiscardCancel => 'Cancelar';

  @override
  String get modelSave => 'Guardar';

  @override
  String get modelUnsavedMaxTokens =>
      'Los tokens de salida máximos están habilitados pero no tienen valor.';

  @override
  String get modelMaxTokensPositive =>
      'Los tokens de salida máximos deben ser un número entero positivo.';

  @override
  String get modelSeedInteger =>
      'La semilla aleatoria debe ser un número entero.';

  @override
  String get modelContextLengthRequired => 'Se requiere longitud de contexto.';

  @override
  String get modelContextLengthPositive =>
      'La longitud del contexto debe ser un número entero positivo.';

  @override
  String get modelAsrLanguageCode => 'Código de idioma (Idioma)';

  @override
  String get modelAsrLanguageHint => 'p.ej. zh, en, ja';

  @override
  String get modelAsrLanguageHelp =>
      'Código de idioma ISO-639-1; déjelo vacío para la detección automática.';

  @override
  String get modelTemperature => 'Temperatura';

  @override
  String get modelTemperatureHelp =>
      'Controla la aleatoriedad de la salida; Se recomienda un valor más bajo.';

  @override
  String get modelAsrPrompt => 'Instrucción';

  @override
  String get modelAsrPromptHint => 'Ingrese un mensaje de contexto (opcional)';

  @override
  String get modelAsrPromptHelp =>
      'Proporcione contexto para mejorar la precisión de la transcripción, como una lista de términos especializados.';

  @override
  String get modelAsrParams => 'Parámetros ASR';

  @override
  String get modelEnabledParamsHelp =>
      'Los parámetros habilitados se envían de forma predeterminada en las solicitudes de API.';

  @override
  String get modelAsrResponseFormat => 'Formato de respuesta';

  @override
  String get modelAsrResponseHelp => 'Formato de la transcripción devuelta.';

  @override
  String get modelAsrTimestampGranularity =>
      'Granularidad de la marca de tiempo';

  @override
  String get modelAsrVerboseHelp =>
      'Disponible solo cuando el formato_respuesta es verbose_json.';

  @override
  String get modelNoTrim => 'Sin recortes';

  @override
  String get modelAudioTrimTitle => 'Recorte de audio';

  @override
  String get modelAudioTrimHelp => 'Elija cómo recortar el audio.';

  @override
  String get modelDeleteTrimPreset => 'Eliminar ajuste preestablecido';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return '¿Eliminar ajuste preestablecido \"$name\"?';
  }

  @override
  String get modelAddTrimPreset => 'Agregar adornos personalizados';

  @override
  String get modelPlayTestAudio => 'Reproducir audio de prueba';

  @override
  String get modelPlayingTestAudio => 'Jugando...';

  @override
  String get modelParamExists => 'El parámetro ya existe';

  @override
  String get asrModelIdExample => 'p.ej. susurro-1';

  @override
  String get asrPromptLabel => 'Instrucción';

  @override
  String get asrResponseFormatJson => 'json-JSON';

  @override
  String get asrResponseFormatText => 'texto – texto sin formato';

  @override
  String get asrResponseFormatSrt => 'srt – Subtítulos';

  @override
  String get asrResponseFormatVtt => 'vtt – Subtítulos';

  @override
  String get asrResponseFormatVerbose =>
      'verbose_json: JSON detallado (incluye marcas de tiempo)';

  @override
  String get asrVerboseTimestampHelp =>
      'Al seleccionar verbose_json se habilita la opción de granularidad de marca de tiempo a continuación.';

  @override
  String get asrTimestampSegment => 'segmento – nivel de segmento';

  @override
  String get asrTimestampWord => 'palabra – nivel de palabra';

  @override
  String get asrWordTimestampHelp =>
      'Las marcas de tiempo a nivel de palabra pueden ser menos precisas que las marcas de tiempo a nivel de segmento.';

  @override
  String get reasoningAddOptionValue => 'Agregar valor de opción';

  @override
  String get reasoningEditOptionValue => 'Editar valor de opción';

  @override
  String get reasoningOptionExample => 'p.ej. bajo, medio, alto';

  @override
  String get reasoningOptionSelectionHelp =>
      'Toque un chip para seleccionarlo o borrarlo. Se envían los valores seleccionados; arrastre para reordenar. Los valores del proveedor no se pueden eliminar, pero se pueden ocultar al borrarlos.';

  @override
  String get reasoningAddOption => 'Agregar opción';

  @override
  String get reasoningCurrentProvider => 'Actual: proveedor';

  @override
  String get reasoningCurrentModel => 'Actual: modelo personalizado';

  @override
  String get reasoningAddEffortValue =>
      'Agregue valor al esfuerzo de razonamiento';

  @override
  String get reasoningEffortExample => 'p.ej. máximo, ultra, profundo';

  @override
  String get reasoningAddToggle => 'Agregar palanca de razonamiento';

  @override
  String get reasoningToggle => 'alternar razonamiento';

  @override
  String get reasoningResetParameter => 'Restablecer este parámetro';

  @override
  String get reasoningDisableToggle => 'Deshabilitar el cambio de razonamiento';

  @override
  String get reasoningEnableToggle => 'Habilitar alternancia de razonamiento';

  @override
  String reasoningParameterNameSource(String source) {
    return 'Nombre del parámetro ($source)';
  }

  @override
  String get reasoningNameExample => 'p.ej. tipo de pensamiento, razonamiento';

  @override
  String get reasoningBooleanHelp =>
      'Los parámetros booleanos no necesitan valor; el panel de chat proporciona un interruptor de encendido/apagado.';

  @override
  String get reasoningOnValue => 'Valor cuando está habilitado';

  @override
  String get reasoningOnExample => 'p.ej. habilitado, verdadero';

  @override
  String get reasoningOffValue => 'Valor cuando está deshabilitado';

  @override
  String get reasoningOffExample => 'p.ej. deshabilitado, falso';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return 'Cuando está habilitado, envía “$onValue”; cuando está deshabilitado, envía “$offValue”.';
  }

  @override
  String get reasoningAddEffort => 'Añadir esfuerzo de razonamiento';

  @override
  String get reasoningFillToggleFirst =>
      'Primero complete el cambio de razonamiento';

  @override
  String get reasoningFillToggleBeforeEffort =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get reasoningAddValue => 'Agregar valor';

  @override
  String get reasoningJsonValue => 'valor JSON';

  @override
  String reasoningJsonExample(String example) {
    return 'p.ej. $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      'Toque un chip para seleccionarlo o borrarlo. Los valores seleccionados aparecen en el panel de razonamiento del chat; arrastre para reordenar. Los valores del proveedor no se pueden eliminar, pero se pueden ocultar.';

  @override
  String get reasoningAddParameter => 'Agregar parámetro de razonamiento';

  @override
  String get reasoningToggleIncomplete =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get llmContextLength => 'Longitud del contexto';

  @override
  String get llmContextHint => 'Introduzca la longitud del contexto';

  @override
  String get llmContextHelp =>
      'Tamaño máximo de ventana de contexto para el modelo (tokens).';

  @override
  String get llmReasoningParams => 'Parámetros de razonamiento';

  @override
  String get llmReasoningHelp =>
      'Configurar parámetros de razonamiento para el chat. La palanca de razonamiento controla el nombre del parámetro y los valores de activación/desactivación. Agregue valores de esfuerzo de razonamiento, reordenelos y seleccione qué valores aparecen en el panel de chat. Los valores del proveedor se sincronizan cuando se abre esta página. Estas configuraciones controlan la disponibilidad de los parámetros del modelo; la alternancia del panel de chat se administra por separado.';

  @override
  String get llmAddReasoningParam => 'Agregar parámetro de razonamiento';

  @override
  String get llmCustomEndpointType => 'Tipo de punto final personalizado';

  @override
  String get llmInheritEndpointType =>
      'Cuando esté deshabilitado, use el tipo de punto final de la configuración del proveedor.';

  @override
  String get llmEndpointType => 'Tipo de punto final';

  @override
  String get llmEndpointOpenAi =>
      'Compatible con OpenAI (finalizaciones de chat)';

  @override
  String get llmEndpointAnthropic => 'Formato antrópico (API de mensajes)';

  @override
  String get llmEndpointHelp =>
      'El tipo de punto final debe coincidir con la URL de la API del proveedor. Cambiarlo afecta el formato utilizado para nuevas conversaciones con este modelo.';

  @override
  String get llmTopPHelp =>
      'Parámetro de muestreo del núcleo; controla la probabilidad acumulada para la selección de palabras.';

  @override
  String get llmFrequencyPenaltyLabel => 'Penalización de frecuencia';

  @override
  String get llmFrequencyPenaltyHelp =>
      'Reduce la repetición; los valores negativos lo aumentan.';

  @override
  String get llmPresencePenaltyLabel => 'Penalización de presencia';

  @override
  String get llmPresencePenaltyHelp =>
      'Fomenta nuevos temas; los valores negativos fomentan la repetición.';

  @override
  String get llmMaxTokensHint => 'Opcional, p.e. 4096';

  @override
  String get llmTokensPerResponse => 'Tokens máximos generados por respuesta.';

  @override
  String get llmSeedLabel => 'Semilla aleatoria (Semilla)';

  @override
  String get llmSeedHint => 'Opcional, p.e. 42';

  @override
  String get llmSeedHelp =>
      'Configurar esto hace que la salida sea reproducible.';

  @override
  String get llmInheritedCustomHelp =>
      'Los parámetros personalizados del proveedor se muestran aquí y se sincronizan cada vez que se abre esta página.';

  @override
  String get llmBooleanParamHelp =>
      'Los parámetros booleanos no necesitan un valor.';

  @override
  String get modelContextReq => 'Se requiere longitud de contexto.';

  @override
  String get modelContextPositive =>
      'La longitud del contexto debe ser un número entero positivo.';

  @override
  String modelParamNameInvalid(String name) {
    return 'Nombre de parámetro no válido (los segmentos separados por puntos no pueden estar vacíos): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return 'El parámetro \"$name\" $valueLabel debe ser un número finito: $value';
  }

  @override
  String get modelReasoningIncomplete =>
      'Complete la alternancia de razonamiento antes de habilitar otros parámetros de razonamiento.';

  @override
  String get modelReasoningOptionsRequired =>
      'Agregue al menos un valor de opción al parámetro de razonamiento.';

  @override
  String modelReasoningError(String error) {
    return 'Error de parámetro de razonamiento: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return 'Parámetro de razonamiento duplicado: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return 'El razonamiento y los parámetros personalizados comparten el nombre: $name';
  }

  @override
  String get modelSeedRequired =>
      'La semilla aleatoria está habilitada pero vacía.';

  @override
  String get ocrParamsTitle => 'Parámetros de OCR';

  @override
  String get ocrParamsHelp =>
      'Utiliza el formato de finalización de chat de visión compatible con OpenAI. Los parámetros siguientes son opcionales; Los parámetros no configurados o deshabilitados no se envían. Agregue los parámetros específicos del proveedor a continuación si su API lo admite.';

  @override
  String get ocrRequestSizeOverride => 'Solicitar anulación de tamaño JSON';

  @override
  String get ocrInheritProvider =>
      'Déjelo vacío para heredar la configuración del proveedor';

  @override
  String get ocrBudgetDefault =>
      'Cuando está vacío, hereda la configuración del proveedor; si el proveedor no tiene valor, el valor predeterminado es 20 MiB.';

  @override
  String ocrBudgetValue(String size) {
    return 'Cuando está vacío, hereda la configuración del proveedor ($size MiB); si el proveedor no tiene valor, el valor predeterminado es 20 MiB.';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return 'Revestimiento $direction ${seconds}s';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return 'Recorte los primeros $seconds';
  }

  @override
  String get audioTrimNone => 'No recortar audio';

  @override
  String get trimNameLabel => 'Nombre del método de recorte *';

  @override
  String get trimNameHint => 'p.ej. recorte de silencio';

  @override
  String get trimDurationLabel => 'Duración del recorte (segundos) *';

  @override
  String get trimDurationHint => 'p.ej. 0.123';

  @override
  String get trimNameAndDurationRequired =>
      'El nombre y la duración son obligatorios.';

  @override
  String get trimDurationInvalid => 'Introduzca una duración positiva válida.';

  @override
  String get testAudioHostMissing => 'El host no está configurado.';

  @override
  String get testAudioKeyMissing => 'La clave no está configurada.';

  @override
  String testAudioContentTypeError(String contentType) {
    return 'El tipo de contenido de respuesta es $contentType, no audio.';
  }

  @override
  String get testAudioEmpty => 'El servidor devolvió datos de audio vacíos.';

  @override
  String testAudioTimeoutConnection(String details) {
    return 'Se agotó el tiempo de conexión. Comprueba tu red. $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return 'Recibir tiempo de espera agotado; el servidor respondió demasiado lento. $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return 'Solicitud cancelada. $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return 'Error de red: $message';
  }

  @override
  String get testAudioNoBody => 'Sin cuerpo de respuesta';

  @override
  String testAudioCorsHelp(String details) {
    return 'No se puede conectar al servidor. En la web, esto puede deberse a CORS o a una URL de API incorrecta. Verifique la URL de la API del proveedor y si el servidor permite solicitudes de origen cruzado. $details';
  }

  @override
  String get trimModelNameHint =>
      'Un nombre descriptivo para visualización e identificación, p. \"GPT-4o MiniTTS\". Utilice diferentes nombres para distinguir modelos del mismo proveedor.';

  @override
  String get trimModelIdHelp =>
      'Identificador único utilizado en llamadas API, p. \"gpt-4o-mini-tts\". Debe coincidir con el ID del modelo proporcionado por el proveedor.';

  @override
  String get ttsVoiceRangeTitle => 'rango de volumen';

  @override
  String get ttsMinVolume => 'Volumen mínimo';

  @override
  String get ttsMaxVolume => 'Volumen máximo';

  @override
  String get ttsSpeedRangeTitle => 'Rango de velocidad';

  @override
  String get ttsMinSpeed => 'Velocidad mínima';

  @override
  String get ttsMaxSpeed => 'Velocidad máxima';

  @override
  String get ttsMaxAudioLength => 'Duración máxima de audio por solicitud *';

  @override
  String get ttsAudioLengthHint => 'p.ej. 1000';

  @override
  String get ttsNoVoices => 'Sin voces. Toque para editar.';

  @override
  String get ttsInstructionSupported =>
      'El modelo admite el parámetro de instrucción.';

  @override
  String get ttsInstructionHelp =>
      'Cuando están habilitadas, las solicitudes TTS pueden incluir instrucciones sobre tono, emoción, velocidad de habla y más.';

  @override
  String get ttsStreamSupported => 'El modelo admite salida de streaming';

  @override
  String get ttsStreamHelp =>
      'Habilita este modelo para escenarios de streaming. Confirme que el modelo admita la transmisión antes de habilitarla.';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return 'El parámetro “$name” debe ser verdadero o falso: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired =>
      'Se requiere una duración máxima de audio por solicitud; introduzca un número entero positivo.';

  @override
  String get asrLanguageExample => 'p.ej. zh, en, ja';

  @override
  String get llmReasoningFullHelp =>
      'La palanca de razonamiento controla si se envía el razonamiento y le permite definir el nombre del parámetro y los valores de activación/desactivación. Hay un parámetro de esfuerzo de razonamiento. Seleccione valores y arrástrelos para reordenarlos; Los valores seleccionados aparecen en el panel de razonamiento del chat. Agregue otros parámetros de razonamiento a continuación. Los nombres de los parámetros admiten notación de puntos como think.type, que se convierte en un objeto JSON anidado. Los parámetros de razonamiento del proveedor se sincronizan cuando se abre esta página. Los interruptores aquí controlan los parámetros del modelo; la palanca de razonamiento del chat está separada.';

  @override
  String get llmTemperatureHelp =>
      'Controla la aleatoriedad de la salida; Los valores más altos son más creativos.';

  @override
  String get llmBooleanValueHelp =>
      'Los parámetros booleanos no necesitan un valor.';

  @override
  String get reasoningDisableEffort =>
      'Deshabilitar el esfuerzo de razonamiento';

  @override
  String get reasoningEnableEffort => 'Habilitar el esfuerzo de razonamiento';

  @override
  String get ocrJsonSizePositive =>
      'El tamaño JSON de la solicitud debe ser un valor MiB positivo.';

  @override
  String ttsRangePair(String kind) {
    return 'Ingrese el $kind mínimo y máximo, o déjelos vacíos.';
  }

  @override
  String get ttsEditTrimTitle => 'Editar recorte personalizado';

  @override
  String ttsVoicesCount(String count) {
    return 'Voces ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return 'Generado en el formato de solicitud: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'Introduzca un nombre de servidor MCP.';

  @override
  String get mcpStdioCommandRequired => 'El modo stdio requiere un comando.';

  @override
  String get mcpSseUrlRequired => 'El modo SSE requiere una URL.';

  @override
  String get mcpEditServerTitle => 'Editar servidor MCP';

  @override
  String get mcpCreateServerTitle => 'Nuevo servidor MCP';

  @override
  String get mcpUnsavedChangesTitle => 'Cambios no guardados';

  @override
  String get mcpUnsavedChangesConfirm =>
      'Tienes cambios sin guardar. ¿Descartarlos?';

  @override
  String get mcpTransportType => 'Tipo de transporte';

  @override
  String get mcpServerName => 'Nombre del servidor';

  @override
  String get mcpServerNameHint => 'Introduzca un nombre de servidor MCP';

  @override
  String get mcpCommand => 'Dominio';

  @override
  String get mcpCommandExample => 'Ejemplo: npx';

  @override
  String get mcpArguments => 'Argumentos';

  @override
  String get mcpArgumentsHint =>
      'Separe los argumentos con comas, por ejemplo: -y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => 'Ejemplo: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'clave API';

  @override
  String get mcpApiKeyHint => 'Ingrese una clave API (opcional)';

  @override
  String get mcpShowKey => 'Mostrar clave';

  @override
  String get mcpHideKey => 'Ocultar clave';

  @override
  String get mcpDescriptionHint =>
      'Ingrese una descripción para este servidor MCP (opcional)';

  @override
  String get mcpStdioDescription =>
      'stdio inicia un proceso secundario local como servidor MCP y se comunica a través de entrada/salida estándar. Recomendado para herramientas locales.';

  @override
  String get mcpSseDescription =>
      'SSE se conecta a un servidor MCP remoto a través de HTTP SSE. Recomendado para servicios remotos.';

  @override
  String get mcpLocalStdio => 'Local (esdio)';

  @override
  String get mcpRemoteSse => 'Remoto (SSE)';

  @override
  String get mcpSaving => 'Ahorro…';

  @override
  String get providerTestSafetyNote =>
      'Esta prueba envía una solicitud real al servicio seleccionado. MCP solo llama al método de lista/herramientas de solo lectura; HTTP y la búsqueda web ejecutan una consulta. Todo lee la lista de forma predeterminada; Para proteger los datos actuales, omita el parámetro todos o configúrelo en nulo.';

  @override
  String get providerDeleteConfigTitle => 'Eliminar configuración';

  @override
  String get providerDeleteConfigConfirm =>
      '¿Eliminar esta configuración de proveedor y todos sus modelos?';

  @override
  String get providerCreateGroup => 'Nuevo grupo';

  @override
  String get providerEditGroup => 'Editar grupo';

  @override
  String get providerGroupName => 'Nombre del grupo';

  @override
  String get providerGroupNameExists => 'Ya existe un grupo con este nombre.';

  @override
  String get providerDeleteGroup => 'Eliminar grupo';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return 'Al eliminar \"$groupName\", sus configuraciones se moverán a \"Otros servicios MCP\".';
  }

  @override
  String get providerMoveToGroup => 'Mover al grupo';

  @override
  String get providerUnnamed => '(Sin nombre)';

  @override
  String get providerHttpSearch => 'búsqueda HTTP';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'Herramienta HTTP: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return 'Local (diodo estándar): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return 'Remoto (SSE): $url';
  }

  @override
  String get providerServices => 'Configuraciones de servicio';

  @override
  String get providerServicesDescription =>
      'Administre conexiones remotas, stdio local y búsqueda HTTP por grupo';

  @override
  String get providerCreateGroupAction => 'Nuevo grupo';

  @override
  String get providerGroupEmpty =>
      'Este grupo no tiene configuraciones. Seleccione \"Agregar\" para agregar un elemento.';

  @override
  String get providerBuiltinTools => 'Herramientas integradas';

  @override
  String get providerBuiltinToolsDescription =>
      'Interfaces de herramientas locales proporcionadas por Stroom. La búsqueda web aparece en su grupo de servicios.';

  @override
  String get providerBuiltinToolInterface =>
      'Interfaz de herramienta incorporada';

  @override
  String get providerViewInterface => 'Ver interfaz';

  @override
  String get providerConfigTitle => 'Configuración';

  @override
  String get providerNotFound => 'Proveedor no encontrado';

  @override
  String get providerConfigurationHeading => 'Configuración del proveedor';

  @override
  String get providerBuiltinWebSearchEmpty =>
      'La búsqueda web integrada es compatible con Google, Bing y Baidu. El nombre de su herramienta modelo es web_search.';

  @override
  String get providerNoConfigsAdd =>
      'Aún no hay configuraciones de proveedor. Seleccione \"Agregar\" para crear uno.';

  @override
  String get providerNoHost => '(Anfitrión no configurado)';

  @override
  String get providerServicesAndTools => 'Servicios y herramientas';

  @override
  String get providerManageServicesDescription =>
      'Administre servidores MCP, búsqueda HTTP y herramientas integradas de Stroom.';

  @override
  String get providerNoServices => 'Aún no hay configuraciones de servicio';

  @override
  String get providerAddServiceDescription =>
      'Agregue un servicio MCP o una interfaz de búsqueda HTTP para usarlo en asistentes.';

  @override
  String get providerAddService => 'Agregar servicio';

  @override
  String get providerBuiltinBadge => 'Incorporado';

  @override
  String get providerBuiltinTtsName => 'Proveedor de TTS';

  @override
  String get providerBuiltinLlmName => 'Proveedor de Maestría en Derecho';

  @override
  String get providerBuiltinOcrName => 'Proveedor de OCR';

  @override
  String get providerBuiltinAsrName => 'Proveedor de reconocimiento de voz';

  @override
  String get providerBuiltinMcpName => 'Proveedor MCP';

  @override
  String get providerBuiltinSearchGroupName => 'Buscar';

  @override
  String get providerBuiltinMcpServicesGroupName => 'Otros servicios de MCP';

  @override
  String get providerConnectivityTest => 'Prueba de conectividad';

  @override
  String get providerMoveGroupTooltip => 'Mover al grupo';

  @override
  String get providerDeleteTooltip => 'Eliminar configuración';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# elementos',
      one: '# elemento',
      zero: 'No hay elementos',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => 'Acciones grupales';

  @override
  String get providerEditGroupAction => 'Editar grupo';

  @override
  String get providerDeleteGroupAction => 'Eliminar grupo';

  @override
  String get providerAddItem => 'Agregar artículo';

  @override
  String get providerMcpMasterLabel => 'Servidores MCP';

  @override
  String get providerMcpMasterDescription =>
      'Controla si los servidores MCP y las herramientas de búsqueda integradas están disponibles en asistentes y chats.';

  @override
  String get providerEnabled => 'Activado';

  @override
  String get providerDisabled => 'Desactivado';

  @override
  String get providerEditSettings => 'Editar la configuración del proveedor';

  @override
  String get providerModelList => 'Modelos';

  @override
  String get providerNoModels => 'Aún no hay modelos';

  @override
  String get providerDeleteModel => 'Eliminar modelo';

  @override
  String get providerDeleteModelConfirm =>
      '¿Estás seguro de que deseas eliminar este modelo?';

  @override
  String get providerEditConfig => 'Editar configuración';

  @override
  String providerCreateNamedConfig(String entryName) {
    return 'Nueva configuración $entryName';
  }

  @override
  String get toolHttpSearchType => 'Tipo de conexión: búsqueda HTTP';

  @override
  String toolInterface(String name) {
    return 'Interfaz de herramienta: $name';
  }

  @override
  String get toolParameterDefinitions => 'Definiciones de parámetros';

  @override
  String get toolHttpAddress => 'URL de punto final HTTP';

  @override
  String get toolInvalidHttpUrl => 'Introduzca una URL HTTP o HTTPS válida.';

  @override
  String get toolBuiltinType =>
      'Tipo de conexión: herramienta incorporada Stroom';

  @override
  String get toolBuiltinEnableHelp =>
      'Habilite esta herramienta para un asistente en la configuración de herramientas predeterminada de ese asistente.';

  @override
  String get mcpSseUrlLabel => 'URL SSE';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return 'ID del modelo: $modelId';
  }

  @override
  String get providerValueNotSet => '(No establecido)';

  @override
  String get providerApiKeyInputHint => 'Ingrese una clave API';

  @override
  String get providerSettingsTitle => 'Configuración del proveedor';

  @override
  String get providerBasicInfoTab => 'Información básica';

  @override
  String get providerParameterSettingsTab => 'Configuración de parámetros';

  @override
  String get providerOptionValuesReorderHelp =>
      'Valores de opciones (mantenga presionado el controlador para arrastrar y reordenar)';

  @override
  String providerOptionIndexLabel(String index) {
    return 'Opción $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return 'p.ej. $example';
  }

  @override
  String get providerDeleteOptionTooltip => 'Eliminar opción';

  @override
  String get providerAddOption => 'Agregar opción';

  @override
  String get providerAddCustomParam => 'Agregar parámetro';

  @override
  String get providerNoCustomParams => 'Aún no hay parámetros personalizados';

  @override
  String get providerParamNameLabel => 'Nombre del parámetro';

  @override
  String get providerParamDefaultValueLabel =>
      'Valor de parámetro predeterminado';

  @override
  String get providerBooleanParamNoValue =>
      'Los parámetros booleanos no necesitan un valor. El panel de chat proporciona un interruptor de encendido/apagado.';

  @override
  String get providerReasoningParamsHeading => 'Parámetros de razonamiento';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return 'La palanca de razonamiento activa o desactiva el razonamiento en el chat; usted elige el nombre del parámetro y los valores de activación/desactivación. Puede configurar un parámetro de esfuerzo de razonamiento con un nombre obligatorio y opciones opcionales. Si ingresa solo un nombre, la configuración del modelo puede proporcionar los valores. Utilice los botones siguientes para agregar otros parámetros de razonamiento. Los nombres de los parámetros admiten el anidamiento de puntos; por ejemplo, $parameterName se expande a $jsonExample.';
  }

  @override
  String get providerAddReasoningParam => 'Agregar parámetro de razonamiento';

  @override
  String get providerAddReasoningToggle => 'Agregar palanca de razonamiento';

  @override
  String get providerReasoningToggle => 'alternar razonamiento';

  @override
  String get providerDeleteReasoningToggle =>
      'Eliminar palanca de razonamiento';

  @override
  String providerParamNameHint(String examples) {
    return 'p.ej. $examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      'Los parámetros booleanos no necesitan un valor. El panel de chat proporciona un interruptor de encendido/apagado.';

  @override
  String get providerToggleOnValueLabel => 'En valor';

  @override
  String get providerToggleOffValueLabel => 'Valor apagado';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return 'Cuando el razonamiento esté activado, envíe “$onValue”; cuando esté apagado, envíe “$offValue”.';
  }

  @override
  String get providerAddReasoningEffort => 'Añadir esfuerzo de razonamiento';

  @override
  String get providerDeleteReasoningEffort =>
      'Eliminar parámetro de esfuerzo de razonamiento';

  @override
  String get providerReasoningEffortLockedHint =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get providerJsonValueLabel => 'valor JSON';

  @override
  String get providerReasoningOptionsHelp =>
      'Valores de opción (opcional; si solo se ingresa el nombre del parámetro, la configuración del modelo proporciona el valor). Mantenga presionada la manija para arrastrar y reordenar.';

  @override
  String get providerParamNameNestedLabel =>
      'Nombre del parámetro (admite anidamiento de puntos)';

  @override
  String get providerToggleEffortPrerequisite =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get providerToggleRequiredHint =>
      'Primero complete el cambio de razonamiento.';

  @override
  String get providerDeleteCustomParam => 'Eliminar parámetro';

  @override
  String get modelSaveSuccess => 'Modelo guardado';

  @override
  String get modelSaving => 'Ahorro…';

  @override
  String modelOriginalError(String error) {
    return 'Error original: $error';
  }

  @override
  String get paramTypeStringLabel => 'Cadena';

  @override
  String get paramTypeNumberLabel => 'Número';

  @override
  String get paramTypeBooleanLabel => 'Booleano';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return 'Tipo no compatible: $type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return 'El parámetro “$name” utiliza el tipo “$type” no admitido. Reemplácelo con un tipo compatible o elimine el parámetro antes de guardar.';
  }

  @override
  String get paramTypeStringHint => 'p.ej. alegre';

  @override
  String get paramTypeNumberHint => 'p.ej. 0,8';

  @override
  String get paramTypeBooleanHint => 'p.ej. verdadero';

  @override
  String get paramTypeJsonHint => 'p.ej.';

  @override
  String get ankiPageTitle => 'Tarjetas didácticas de Anki';

  @override
  String get ankiStatsTooltip => 'Estadísticas del estudio';

  @override
  String get ankiBrowseCardsTooltip => 'Explorar tarjetas';

  @override
  String get ankiStatsTotalCards => 'Tarjetas totales';

  @override
  String get ankiStatsNewCards => 'Nuevas cartas';

  @override
  String get ankiStatsLearning => 'Aprendiendo';

  @override
  String get ankiStatsDueForReview => 'Debido a revisión';

  @override
  String get ankiStatsReviewHistory => 'Revisar el historial';

  @override
  String get ankiStatsLearningProgress => 'Progreso del estudio';

  @override
  String get ankiStatsReviewRate => 'Tasa de revisión';

  @override
  String get ankiBrowserSearchHint => 'Buscar tarjetas...';

  @override
  String get ankiBrowserEmpty => 'sin tarjetas';

  @override
  String get ankiSyncTooltip => 'Sincronización AnkiWeb';

  @override
  String get ankiNewDeckTooltip => 'Nueva baraja';

  @override
  String ankiDeckLoadError(String error) {
    return 'No se pudieron cargar las plataformas: $error';
  }

  @override
  String get ankiEmptyDecksTitle => 'Aún no hay mazos';

  @override
  String get ankiEmptyDecksDescription =>
      'Crea un mazo para empezar a estudiar';

  @override
  String get ankiNewDeckTitle => 'Nueva baraja';

  @override
  String get ankiDeckNameHint => 'Nombre de la plataforma';

  @override
  String get ankiCreateDeck => 'Crear';

  @override
  String get ankiRenameDeck => 'Cambiar nombre de mazo';

  @override
  String get ankiConfirm => 'DE ACUERDO';

  @override
  String get ankiDeleteDeckTitle => 'Eliminar mazo';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '¿Eliminar “$deckName” y todas sus tarjetas?';
  }

  @override
  String get ankiAddCardTitle => 'Agregar tarjeta';

  @override
  String get ankiNoteTypeLabel => 'tipo de nota';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return 'Texto (marcar eliminaciones con $clozeSyntax)';
  }

  @override
  String get ankiFrontQuestionHint => 'Frente (pregunta)';

  @override
  String get ankiBackExtraLabel => 'Atrás/extra';

  @override
  String get ankiTagsLabel => 'Etiquetas (separadas por espacios)';

  @override
  String get ankiTagsHint => 'Ejemplo: física matemática';

  @override
  String get ankiAdd => 'Agregar';

  @override
  String get ankiStatNew => 'Nuevo';

  @override
  String get ankiStatLearning => 'Aprendiendo';

  @override
  String get ankiStatReview => 'Revisar';

  @override
  String get ankiAddCardAction => 'Agregar tarjeta';

  @override
  String get ankiRenameAction => 'Rebautizar';

  @override
  String get ankiDeleteAction => 'Borrar';

  @override
  String get ankiNoCardContent => 'Sin contenido de tarjeta';

  @override
  String get ankiStudy => 'Estudiar';

  @override
  String get ankiWhiteboardTooltip => 'Pizarra';

  @override
  String get ankiFrontLabel => 'Frente';

  @override
  String get ankiBackLabel => 'Atrás';

  @override
  String get ankiShowAnswer => 'Mostrar respuesta';

  @override
  String get ankiRatingAgain => 'De nuevo';

  @override
  String get ankiRatingHard => 'Duro';

  @override
  String get ankiRatingGood => 'Bien';

  @override
  String get ankiRatingEasy => 'Fácil';

  @override
  String get ankiNoCardsToStudy => 'No hay tarjetas para estudiar ahora mismo.';

  @override
  String get ankiNoCardsHint => 'Añade nuevas tarjetas o vuelve más tarde';

  @override
  String get ankiBack => 'Atrás';

  @override
  String get ankiSyncPageTitle => 'sincronización de anki';

  @override
  String get ankiSyncChooseMode => 'Elija un modo de sincronización';

  @override
  String get ankiSyncModeHelp =>
      'El estado de inicio de sesión se almacena por separado para cada servicio. El cambio de modos no fusiona ni sobrescribe datos.';

  @override
  String get ankiSyncSelfHostedMode => 'Servidor autohospedado';

  @override
  String get ankiSyncServerAddress => 'Dirección del servidor';

  @override
  String get ankiSyncServerHelp =>
      'Los servidores remotos autohospedados deben utilizar HTTPS; Se permite HTTP para direcciones locales. El servidor debe admitir Anki sync v10 y la verificación de certificados está habilitada de forma predeterminada.';

  @override
  String get ankiSyncCustomCaTitle => 'Certificado CA personalizado (opcional)';

  @override
  String get ankiSyncCustomCaHelp =>
      'Ingrese esto solo cuando el servidor use un certificado autofirmado';

  @override
  String get ankiSyncOfficialHelp =>
      'Utilice el servicio de sincronización oficial de AnkiWeb. Su contraseña se envía solo al iniciar sesión y no se almacena en Stroom.';

  @override
  String ankiSyncConnected(String service) {
    return 'Conectado a $service';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return 'No conectado a $service';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return 'Inicie sesión en $service';
  }

  @override
  String get ankiSyncCheckServerStatus => 'Verificar el estado del servidor';

  @override
  String get ankiSyncLogout => 'Finalizar la sesión';

  @override
  String get ankiSyncBothWays => 'Sincronización bidireccional';

  @override
  String get ankiSyncOverwriteServer =>
      'Reemplazar datos del servidor con datos locales';

  @override
  String get ankiSyncReplaceLocal =>
      'Reemplazar datos locales con datos del servidor';

  @override
  String get ankiSyncHelp =>
      'La sincronización bidireccional fusiona cambios incrementales de colección y transfiere archivos multimedia. Si la versión del esquema difiere, elija una carga o descarga completa. Una descarga completa fallida intentará restaurar la colección original y el directorio multimedia.';

  @override
  String get ankiSyncStatusRestored =>
      'Restableció la sesión de inicio de sesión guardada de forma segura';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      'No se pudo leer la sesión de inicio de sesión guardada. Por favor inicia sesión nuevamente.';

  @override
  String get ankiSyncInvalidServerUrl =>
      'La dirección del servidor debe ser una URL HTTPS. HTTP sólo se permite para una dirección de loopback local. No se permiten información de usuario ni parámetros de consulta.';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return 'Configuración no guardada: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      'La dirección del servidor cambió. Por favor inicie sesión nuevamente para continuar.';

  @override
  String get ankiSyncStatusVerifyingLogin => 'Verificando inicio de sesión…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      'Inicie sesión exitosamente. Su contraseña no fue guardada; la clave de sincronización fue cifrada y guardada.';

  @override
  String get ankiSyncLoginSuccessPromptTitle => 'Inicio de sesión exitoso';

  @override
  String get ankiSyncLoginSuccessPromptMessage =>
      '¿Desea sincronizar su colección ahora?';

  @override
  String get ankiSyncLoginSuccessPromptSync => 'Sincronizar ahora';

  @override
  String get ankiSyncLoginSuccessPromptLater => 'Continuar';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      'Inicie sesión correctamente, pero la clave de sincronización no se pudo almacenar de forma segura. Deberá iniciar sesión nuevamente después de cerrar esta página.';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'Inicie sesión en AnkiWeb';

  @override
  String get ankiSyncLoginSelfHosted =>
      'Inicie sesión en el servidor autohospedado';

  @override
  String get ankiSyncEmailOrUsername => 'Correo electrónico/nombre de usuario';

  @override
  String get ankiSyncEmailOrUsernameRequired =>
      'Introduzca un correo electrónico o nombre de usuario';

  @override
  String get ankiSyncPassword => 'Contraseña';

  @override
  String get ankiSyncPasswordRequired => 'Introduce una contraseña';

  @override
  String get ankiSyncLogin => 'Acceso';

  @override
  String get ankiSyncStatusPreparingServerSettings =>
      'Preparando la configuración del servidor…';

  @override
  String get ankiSyncStatusReadingCollection =>
      'Leyendo el estado de la recopilación del servidor...';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      'Conectado. La colección del servidor está vacía.';

  @override
  String get ankiSyncStatusConnectedStatusRead =>
      'Conectado. Se leyó el estado del servidor.';

  @override
  String get ankiSyncStatusUpgradeClient =>
      'Este servidor requiere un cliente de sincronización más nuevo.';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return 'Error en la verificación de estado: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload =>
      'Preparando la configuración de carga...';

  @override
  String get ankiSyncOverwriteServerConfirmTitle =>
      '¿Reemplazar la colección del servidor por la local?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      'La colección del servidor será reemplazada completamente con datos locales. Stroom primero mantendrá una copia de seguridad de la base de datos local.\n\nLos archivos multimedia seguirán estando sincronizados en ambas direcciones según la lista de medios del servidor.';

  @override
  String get ankiSyncOverwriteServerAction =>
      'Reemplazar la colección del servidor';

  @override
  String get ankiSyncStatusBackingUpUploading =>
      'Copia de seguridad y carga de la colección...';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return 'El servidor aceptó la recogida local. Sincronización de medios completada: archivos $uploaded cargados, $downloaded descargados, $deleted eliminado.$backup Verifique el estado del servidor nuevamente.';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return 'Copia de seguridad local: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      'Se reemplazó la colección del servidor, pero la sincronización de medios no finalizó:';

  @override
  String get ankiSyncStatusUploadFailed => 'La carga falló:';

  @override
  String get ankiSyncStatusPreparingDownload =>
      'Preparando la configuración de descarga…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle =>
      '¿Reemplazar la colección local con la del servidor?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      'La colección local será reemplazada por datos del servidor. Stroom primero mantendrá una copia de seguridad de la base de datos local.\n\nLos medios del servidor reemplazarán los medios locales y se descargarán los archivos faltantes. Si algún paso falla o la aplicación se cierra en el medio, Stroom restaurará la colección y los medios locales antes de abrir las plataformas la próxima vez.';

  @override
  String get ankiSyncReplaceLocalAction => 'Reemplazar datos locales';

  @override
  String get ankiSyncStatusDownloadingValidating =>
      'Descargando y validando colección…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return 'La colección local fue reemplazada y pasó la verificación de SQLite. Sincronización de medios completada: archivos $downloaded descargados, $uploaded cargados, $deleted eliminado.$backup Verifique el estado del servidor nuevamente.';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return 'Descarga fallida: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => 'Preparando sincronización…';

  @override
  String get ankiSyncStatusMergingChanges =>
      'Fusionando cambios de colección...';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'Los cambios de colección se fusionaron. Sincronizando archivos multimedia…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return 'Notas $notes, tarjetas $cards y registros de revisión $reviews agregados o actualizados';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges =>
      'No hay cambios de colección para fusionar';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return 'Sincronización bidireccional completa: $collection; medios cargados $uploaded, descargados $downloaded, eliminados $deleted.';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'Los cambios de colección se fusionaron, pero la sincronización de medios no finalizó:';

  @override
  String get ankiSyncStatusSyncIncomplete => 'La sincronización no finalizó:';

  @override
  String get ankiSyncStatusClearingLogin =>
      'Borrando la sesión de inicio de sesión…';

  @override
  String get ankiSyncStatusLoggedOut =>
      'Cerrado la sesión. La clave de sincronización se eliminó del almacenamiento seguro.';

  @override
  String get ankiSyncStatusClearLoginFailed =>
      'No se pudo borrar la sesión de inicio de sesión guardada';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      'La operación no terminó. Verifique el almacenamiento seguro, la red y la dirección del servidor.';

  @override
  String get ankiSyncUnknown => 'Desconocido';

  @override
  String get ankiSyncServerCollectionEmpty =>
      'La colección de servidores está vacía';

  @override
  String get ankiSyncServerCollectionAvailable =>
      'La colección de servidores está disponible';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return 'Versión del esquema $schema · USN $usn · Modificado $modified';
  }

  @override
  String get asrPageTitle => 'Transcripción de audio';

  @override
  String get clear => 'Limpiar';

  @override
  String get configure => 'Configurar';

  @override
  String get asrModel => 'Modelo de reconocimiento';

  @override
  String get reselectModel => 'Por favor seleccione un modelo nuevamente';

  @override
  String get selectAsrModel => 'Seleccione un modelo de reconocimiento';

  @override
  String get enterPublicAudioUrl => 'Introduce una URL de audio pública';

  @override
  String get recordingSelection => 'Grabaciones';

  @override
  String get audioFiles => 'Archivos de audio';

  @override
  String get noAudioSelected => 'No hay archivos de audio seleccionados';

  @override
  String get supportedAudioFormats =>
      'Admite formatos de audio comunes como WAV, MP3, M4A y OGG';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos de audio seleccionados',
      one: '$count archivo de audio seleccionado',
      zero: 'No hay archivos de audio seleccionados',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos de audio seleccionados',
      one: '$count archivo de audio seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => 'Seleccionar de nuevo';

  @override
  String get asrUrlLabel => 'URL | Enlace público';

  @override
  String get asrErrorDetails => 'Ver detalles del error';

  @override
  String get asrResultSaved => 'Resultado de la transcripción guardado';

  @override
  String get asrWorking => 'Transcribiendo…';

  @override
  String get asrStart => 'Iniciar transcripción';

  @override
  String get saveTo => 'Guardar en';

  @override
  String get rootFolder => 'Carpeta raíz';

  @override
  String get chooseSaveFolder => 'Elige una carpeta';

  @override
  String get linkAlreadyAdded => 'Este enlace ya está en la lista.';

  @override
  String get chooseAudioSource => 'Elige una fuente de audio';

  @override
  String get inAppRecordings => 'Grabaciones en la aplicación';

  @override
  String get chooseGeneratedRecordings => 'Elija entre grabaciones generadas';

  @override
  String get systemAudioFiles => 'Archivos de audio del sistema';

  @override
  String get chooseDeviceAudioFiles => 'Elija archivos de su dispositivo';

  @override
  String get cannotReadAudioFile => 'No se pudo leer el archivo de audio';

  @override
  String chooseAudioFileFailed(String details) {
    return 'No se pudo seleccionar el archivo de audio: $details';
  }

  @override
  String get chooseInAppRecording => 'Elija grabaciones en la aplicación';

  @override
  String get noRecordings => 'Sin grabaciones';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '$seconds segundo',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider =>
      'Configure primero un proveedor y un modelo de transcripción de audio en Configuración';

  @override
  String get asrModelUnavailable =>
      'El modelo de reconocimiento original no está disponible o no se puede verificar. Por favor seleccione un modelo nuevamente.';

  @override
  String get asrUrlProviderRemoveFiles =>
      'Este proveedor carga audio por URL. Elimine los archivos de audio locales y vuelva a intentarlo.';

  @override
  String get asrFileProviderRemoveUrls =>
      'Este proveedor carga archivos de audio y no admite la transcripción por enlace. Elimina enlaces e inténtalo de nuevo.';

  @override
  String asrTaskStartFailed(String details) {
    return 'No se pudo iniciar la tarea: $details';
  }

  @override
  String get asrInvalidUrl =>
      'URL no válida. Debe comenzar con http:// o https://';

  @override
  String get asrEnterAudioUrl => 'Introduce una URL de audio';

  @override
  String get asrUrlProviderHelp =>
      'Este proveedor carga audio por URL. Ingrese una URL de audio pública (http/https).';

  @override
  String get cancel => 'Cancelar';

  @override
  String get add => 'Agregar';

  @override
  String get ttsPageTitle => 'Audio';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count archivos de audio',
      one: 'Se importó $count archivo de audio',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return 'Error de importación: $details';
  }

  @override
  String get ttsFileReadFailed => 'No se pudieron leer los datos del archivo';

  @override
  String get ttsExportAudioFile => 'Exportar archivo de audio';

  @override
  String ttsExportedTo(String path) {
    return 'Exportado a: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return 'Error al exportar: $details';
  }

  @override
  String get ttsConfirmRegenerate => 'Confirmar regeneración';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return '¿Regenerar audio “$fileName”?';
  }

  @override
  String get ttsRegenerateOverwrite =>
      'El archivo de audio original será reemplazado después de la regeneración.';

  @override
  String get ttsRegenerate => 'regenerar audio';

  @override
  String ttsCopiedFailed(String details) {
    return 'No se pudo copiar: $details';
  }

  @override
  String get ttsChooseExportFolder => 'Elija la carpeta de exportación';

  @override
  String get ttsExportAudio => 'Exportar audio';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se exportaron $count archivos',
      one: 'Se exportó $count archivo',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => 'Exportar carpeta';

  @override
  String get ttsWebFolderExportHelp =>
      'Su navegador no puede elegir una carpeta de exportación. Se descargará un archivo ZIP con la estructura de carpetas conservada.';

  @override
  String get ttsDownloadZip => 'Descargar archivo ZIP';

  @override
  String get ttsExportAudioFolder => 'Exportar carpeta de audio';

  @override
  String get ttsRecord => 'Registro';

  @override
  String get ttsImport => 'Importar';

  @override
  String get ttsPlay => 'Jugar';

  @override
  String get ttsExportLocal => 'Exportar al dispositivo';

  @override
  String get ttsRegenerateQuestion => 'Regenerado';

  @override
  String get ttsNeedsProvider =>
      'Configure primero un proveedor y un modelo de síntesis de voz en Configuración';

  @override
  String get ttsAddedToTasks =>
      'Agregado a la lista de tareas. Generando en segundo plano…';

  @override
  String get ttsCreateTitle => 'Síntesis del habla';

  @override
  String get ttsOriginalTitle => 'Título de la grabación';

  @override
  String get ttsUseOriginalTitle => 'Usar título original';

  @override
  String get ttsAudioFileNameHint =>
      'Nombre del archivo de audio guardado (opcional)';

  @override
  String get ttsTextToConvert => 'Texto para convertir';

  @override
  String get ttsSpeechContent => 'Contenido del discurso';

  @override
  String get ttsTextHint => 'Ingrese el texto para convertirlo a voz...';

  @override
  String get ttsFullscreenEdit => 'Editar en pantalla completa';

  @override
  String ttsTextLimitWarning(int limit) {
    return 'El texto excede el límite (máximo de caracteres $limit)';
  }

  @override
  String get ttsSynthesisConfig => 'Configuración de síntesis';

  @override
  String get ttsVoiceAndSoundHelp => 'Ajustar la voz y el sonido.';

  @override
  String get ttsProviderSettingsLead => 'en';

  @override
  String get ttsProviderSettings => 'Configuración del proveedor TTS';

  @override
  String get ttsProviderSettingsTail => 'para configurar más parámetros';

  @override
  String get ttsEditText => 'Editar texto';

  @override
  String get ttsClose => 'Cerrar';

  @override
  String get ttsVoice => 'Voz';

  @override
  String get ttsSelectVoice => 'Seleccione una voz';

  @override
  String get ttsSpeed => 'Velocidad';

  @override
  String get ttsNormal => 'Normal';

  @override
  String get ttsVolume => 'Volumen';

  @override
  String get ttsInstruction => 'Instrucción de estilo de habla.';

  @override
  String get ttsInstructionHint =>
      'Por ejemplo: Habla en un tono alegre y emocionado.';

  @override
  String get ttsCustomParams => 'Parámetros personalizados';

  @override
  String ttsDefaultValue(Object value) {
    return 'Valor predeterminado: $value';
  }

  @override
  String get ttsGenerateRecording => 'Generar grabación';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return 'Guardar como: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => 'Elige una carpeta';

  @override
  String get ttsFillTextError => 'Ingrese el texto para convertir';

  @override
  String get voiceBatchTitle => 'Añadir voces de forma masiva';

  @override
  String get voiceBatchConfirm => 'Agregar voces seleccionadas';

  @override
  String get voiceBatchSeparator => 'Separador:';

  @override
  String get voiceBatchCustomSeparatorHint =>
      'Introduzca un separador personalizado';

  @override
  String get voiceBatchFieldOrder => 'Orden de campo:';

  @override
  String get voiceBatchNameThenId => '1º = nombre, 2º = DNI';

  @override
  String get voiceBatchIdThenName => '1º = DNI, 2º = nombre';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se detectaron $count columnas. Elija la columna inicial para el nombre/ID:',
      one:
          'Se detectó $count columna. Elija la columna inicial para el nombre/ID:',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return 'Columna $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn =>
      'Se detectó una columna. Todos los valores se utilizarán como ID (nombre = ID).';

  @override
  String get voiceBatchInputHint =>
      'Separe el nombre y el ID con tabulador, coma, punto y coma o barras verticales (un par por línea)';

  @override
  String get voiceBatchNoPreview => 'Nada que previsualizar';

  @override
  String get voiceName => 'Nombre de voz';

  @override
  String get voiceId => 'Identificación de voz';

  @override
  String get status => 'Estado';

  @override
  String get voiceNew => '✅ Nuevo';

  @override
  String get voiceIdExists => '⚠️ La identificación ya existe';

  @override
  String voiceFormatError(String details) {
    return '❌ Error de formato$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ID duplicados encontrados: $ids',
      one: '$count ID duplicado encontrado: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData =>
      'No hay suficientes datos en las columnas seleccionadas';

  @override
  String get voiceCustomSeparator => 'Costumbre…';

  @override
  String get voiceCommaSeparator => 'Coma (,)';

  @override
  String get voiceSemicolonSeparator => 'Punto y coma (;)';

  @override
  String get voicePipeSeparator => 'Barra vertical (|)';

  @override
  String get voiceTabSeparator => 'Pestaña';

  @override
  String get voiceEditorTitle => 'Editar voces';

  @override
  String get save => 'Guardar';

  @override
  String get voiceAddRow => 'Agregar fila';

  @override
  String get voiceBatchAdd => 'Añadir en masa';

  @override
  String get voiceNoneAdd => 'Aún no hay voces. Agregue uno para comenzar.';

  @override
  String get delete => 'Borrar';

  @override
  String get voiceDuplicateResolution =>
      'Las siguientes identificaciones de voz están duplicadas. Elige cómo manejar cada uno:';

  @override
  String get update => 'Actualizar';

  @override
  String get skip => 'Saltar';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count duplicados',
      one: 'Queda $count duplicado',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => 'Continuar editando';

  @override
  String get asrRetryIncomplete =>
      'El audio reintentado está incompleto. Borre la lista y seleccione todo el audio nuevamente.';

  @override
  String asrRetryAudioUnreadable(String details) {
    return 'No se pudieron leer los datos de audio al reintentar. Seleccione el audio nuevamente: $details';
  }

  @override
  String get asrLegacyRetryUnavailable =>
      'El audio de reintento heredado no está disponible. Seleccione el audio nuevamente.';

  @override
  String get asrRetryDataUnreadable =>
      'No se pudieron leer los datos del reintento. Seleccione el audio nuevamente.';

  @override
  String get ttsSynthesisModel => 'Modelo de síntesis';

  @override
  String get asrRetryUnavailable =>
      'Reintentar audio no está disponible. Seleccione el audio nuevamente.';

  @override
  String get chatRequest => 'Pedido';

  @override
  String get chatResponse => 'Respuesta';

  @override
  String get chatNoErrorDetails => 'No hay detalles disponibles';

  @override
  String get ttsInstructionDescription =>
      'Describir tono, emoción, velocidad, acento y otras cualidades en lenguaje natural. El modelo ajusta la voz sintetizada en consecuencia.';

  @override
  String get audioPlayerSourceTextSource => 'Elige el texto fuente';

  @override
  String get audioPlayerChooseInAppText => 'Elija en el texto de la aplicación';

  @override
  String get audioPlayerChooseSavedTextSubtitle =>
      'Elija un archivo de texto guardado desde la aplicación';

  @override
  String get audioPlayerChooseSystemText =>
      'Elija el archivo de texto del sistema';

  @override
  String get audioPlayerChooseDeviceTextSubtitle =>
      'Elija un archivo de texto del almacenamiento del dispositivo';

  @override
  String get audioPlayerSelectInAppText => 'Elija en el texto de la aplicación';

  @override
  String get audioPlayerNoTextFiles => 'Aún no hay archivos de texto';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count caracteres';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return 'No se pudo seleccionar el texto: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile =>
      'No se puede leer el archivo de texto';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return 'No se pudo cargar el texto fuente: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => 'El texto está vacío.';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return 'No se pudo guardar el texto fuente: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => 'Texto fuente subido';

  @override
  String get audioPlayerSourceTextUpdated => 'Texto fuente actualizado';

  @override
  String get audioPlayerConfigureTtsProvider =>
      'Configure primero un proveedor TTS';

  @override
  String get audioPlayerNoStreamingModels =>
      'Ningún modelo admite reproducción en streaming';

  @override
  String get audioPlayerSelectStreamingModel =>
      'Seleccione un modelo de reproducción en streaming';

  @override
  String get audioPlayerProviderFallback => 'Proveedor';

  @override
  String audioPlayerStartStreaming(String model) {
    return 'Iniciando la reproducción en streaming: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return 'Archivo de audio no encontrado: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio =>
      'No se pueden cargar datos de audio';

  @override
  String get audioPlayerSourceText => 'Texto fuente';

  @override
  String get audioPlayerNoSourceText => '(Sin texto fuente)';

  @override
  String get audioPlayerUploadSourceText => 'Subir texto fuente';

  @override
  String get audioPlayerEditSourceText => 'Editar texto fuente';

  @override
  String get audioPlayerCompanionTextMissing =>
      'No se encontró ningún archivo de texto complementario';

  @override
  String get audioPlayerPlaySelection => 'Selección de juego';

  @override
  String get audioPlayerGenerateSelection => 'Generar selección';

  @override
  String get audioPlayerPlaying => 'Jugando...';

  @override
  String get audioPlayerPaused => 'En pausa';

  @override
  String get audioPlayerPlaybackSpeed => 'Velocidad de reproducción';

  @override
  String get audioPlayerFailed => 'Error de reproducción';

  @override
  String get audioPlayerRetry => 'Rever';

  @override
  String get audioPlayerLoading => 'Cargando audio...';

  @override
  String get audioPlayerClose => 'Cerrar';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      'La grabación no es compatible con el navegador. Utilice la versión de la aplicación.';

  @override
  String get audioRecordingMicrophonePermissionRequired =>
      'Se requiere permiso de micrófono para grabar.';

  @override
  String audioRecordingStartFailure(String error) {
    return 'No se pudo iniciar la grabación: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return 'No se pudo pausar la grabación: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return 'No se pudo reanudar la grabación: $error';
  }

  @override
  String get audioRecordingInvalidFile =>
      'El archivo de grabación no es válido. Grabar de nuevo.';

  @override
  String audioRecordingStopFailure(String error) {
    return 'No se pudo detener la grabación: $error';
  }

  @override
  String get audioRecordingFileNotFound => 'Archivo de grabación no encontrado';

  @override
  String get audioRecordingFileEmpty => 'El archivo de grabación está vacío';

  @override
  String audioRecordingSaved(String name) {
    return 'Grabación guardada: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return 'No se pudo guardar la grabación: $error';
  }

  @override
  String get audioRecordingTitle => 'Grabación';

  @override
  String get audioRecordingBrowserUnsupported =>
      'La grabación no es compatible con el navegador.';

  @override
  String get audioRecordingUseApp =>
      'Utilice la versión de la aplicación para grabar';

  @override
  String get audioRecordingDraftRecoveryHint =>
      'Se encontró un borrador de grabación no guardado. Puede guardarlo en la biblioteca de audio.';

  @override
  String get audioRecordingRecording => 'Grabación ●';

  @override
  String get audioRecordingPaused => 'En pausa ||';

  @override
  String get audioRecordingPreparing => 'Preparante...';

  @override
  String get audioRecordingStart => 'Empezar a grabar';

  @override
  String get audioRecordingPause => 'Pausa';

  @override
  String get audioRecordingStopping => 'Parada...';

  @override
  String get audioRecordingStop => 'Detener';

  @override
  String get audioRecordingResume => 'Reanudar';

  @override
  String get audioRecordingSaving => 'Ahorro...';

  @override
  String get audioRecordingSave => 'Guardar grabación';

  @override
  String get audioRecordingRecordAgain => 'Grabar de nuevo';

  @override
  String get audioRecordingWaveformPaused =>
      'Grabación en pausa; la forma de onda está congelada';

  @override
  String get audioRecordingWaveformLive => 'Forma de onda de audio en vivo';

  @override
  String get audioSeparationTitle => 'Separación de audio y vídeo';

  @override
  String get audioSeparationChooseVideoSource => 'Elige la fuente del vídeo';

  @override
  String get audioSeparationChooseAppAlbum =>
      'Elija de la biblioteca de aplicaciones';

  @override
  String get audioSeparationChooseSavedVideoSubtitle =>
      'Elija un video guardado desde la aplicación';

  @override
  String get audioSeparationChooseSystemAlbum =>
      'Elija entre el almacenamiento del sistema';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle =>
      'Elija un archivo de video del almacenamiento del dispositivo';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return 'No se pudo elegir el video: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix =>
      'Error en la extracción de audio:';

  @override
  String get audioSeparationEngineMissing =>
      'Motor de separación de audio no detectado';

  @override
  String get audioSeparationEngineMissingHelp =>
      'Reinicie la aplicación o verifique que sus recursos estén completos.';

  @override
  String get audioSeparationNoVideoSelected => 'Ningún vídeo seleccionado';

  @override
  String get audioSeparationSupportedFormatsHint =>
      'Formatos soportados: mp4, mov, m4v, 3gp';

  @override
  String get audioSeparationSuccess =>
      'Audio extraído y guardado en la biblioteca de audio.';

  @override
  String get audioSeparationView => 'Vista';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se seleccionaron $count videos',
      one: 'Se seleccionó $count video',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => 'Extrayendo...';

  @override
  String get audioSeparationExtractAudio => 'extraer audio';

  @override
  String get audioSeparationSaveTo => 'Guardar en';

  @override
  String get audioSeparationChooseSaveFolder => 'Elija guardar carpeta';

  @override
  String get audioSeparationCannotReadVideoFile =>
      'No se puede leer el archivo de video';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return 'No se pudo seleccionar el archivo de video: $error';
  }

  @override
  String get audioSeparationUnknownFormat => 'Desconocido';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return 'Formatos no compatibles: $formats. Formatos soportados: MP4, MOV, M4V, 3GP.';
  }

  @override
  String get audioSeparationEngineUnavailable =>
      'El motor de separación de audio no está disponible.';

  @override
  String get backgroundOptimizationTitle => 'Optimización de fondo';

  @override
  String get backgroundOptimizationEnvironment => 'Entorno del sistema';

  @override
  String get backgroundOptimizationChecks =>
      'Estado del servicio en segundo plano';

  @override
  String get backgroundOptimizationKeepAliveStrategies =>
      'Estrategias para mantenerse vivo';

  @override
  String get backgroundOptimizationDetecting => 'De cheques…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      'Los servicios en segundo plano no son compatibles con esta plataforma';

  @override
  String get backgroundOptimizationServiceRunning =>
      'El servicio en segundo plano se está ejecutando';

  @override
  String get backgroundOptimizationServiceStopped =>
      'El servicio en segundo plano no se está ejecutando';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      'No se pudo verificar el estado del servicio en segundo plano';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      'La bandeja del escritorio no está disponible. Al cerrar la ventana se saldrá de la aplicación.';

  @override
  String get backgroundOptimizationDesktopCloseExits =>
      'La aplicación se cierra cuando se cierra la ventana del escritorio.';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      'La bandeja del escritorio mantiene la aplicación en funcionamiento.';

  @override
  String get backgroundOptimizationStartFailed =>
      'No se pudo iniciar el servicio';

  @override
  String get backgroundOptimizationStopFailed =>
      'No se pudo detener el servicio';

  @override
  String get backgroundOptimizationRestartFailed =>
      'No se pudo reiniciar el servicio';

  @override
  String get backgroundOptimizationStopService => 'Detener servicio';

  @override
  String get backgroundOptimizationRestartService => 'Reiniciar servicio';

  @override
  String get backgroundOptimizationStartService => 'Iniciar servicio';

  @override
  String get backgroundOptimizationRedetect => 'Comprobar de nuevo';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      'Los controles de servicios en segundo plano no son compatibles con esta plataforma.';

  @override
  String get backgroundOptimizationCheckingBattery =>
      'Comprobando el estado de optimización de la batería...';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      'La optimización de la batería está deshabilitada para esta aplicación';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      'La optimización de la batería está habilitada: es posible que se detenga la actividad en segundo plano';

  @override
  String get backgroundOptimizationIgnoreBattery =>
      'Deshabilitar la optimización de la batería';

  @override
  String get backgroundOptimizationExactAlarm =>
      'Permitir alarmas exactas (actividad en segundo plano más confiable)';

  @override
  String get backgroundOptimizationWatchdogTitle =>
      'Perro guardián del administrador de alarmas';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      'Cuando está habilitado, Android verifica el servicio en segundo plano cada 5 minutos usando una alarma nativa. Si el sistema finaliza el proceso, la alarma lo reinicia.\n\nLa alarma sigue funcionando mientras el dispositivo está en modo Doze y se reprograma después de reiniciar.\n\nRecomendado para usuarios que dependen en gran medida de tareas en segundo plano.\nImpacto de la batería: muy bajo; el dispositivo se activa brevemente para cada comprobación.';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      'No se pudo guardar la configuración de vigilancia; no fue cambiado';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      'No se pudo activar el perro guardián; el estado del servicio en segundo plano no está confirmado';

  @override
  String get backgroundOptimizationColdStartTitle =>
      'Restaurar el servicio al iniciar la aplicación';

  @override
  String get backgroundOptimizationColdStartDetail =>
      'Cuando está habilitada, la aplicación busca y restaura un servicio en segundo plano que se esté ejecutando previamente cada vez que se abre.\n\nSi el sistema o el usuario detiene el proceso de la aplicación, el servicio en segundo plano se reinicia la próxima vez que abra la aplicación.\n\nRecomendado para todos los usuarios.\nImpacto de la batería: ninguno; la aplicación verifica solo una vez al iniciarse.';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      'No se pudo guardar la configuración de recuperación de inicio; no fue cambiado';

  @override
  String get backgroundOptimizationBatteryReminderTitle =>
      'Recordatorio de optimización de la batería';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      'Cuando está habilitada, esta página muestra el estado de optimización de la batería. Si la aplicación no está en la lista de exención de batería, puede abrir la configuración del sistema para eximirla.\n\nLa optimización de la batería de Android (Doze) limita las aplicaciones en segundo plano. Agregar esta aplicación a la lista de exenciones evita que el sistema la detenga para ahorrar energía.\n\nDesactivar esto solo oculta la tarjeta de recordatorio; no cambia la exención de batería de la aplicación.';

  @override
  String get backgroundOptimizationStrategyIntro =>
      'Estas estrategias se pueden habilitar de forma independiente. Todos están activados de forma predeterminada para que la actividad en segundo plano sea más confiable. Desactivar uno afecta sólo a esa estrategia, no al servicio en segundo plano en sí.';

  @override
  String get backgroundOptimizationIosNoteTitle =>
      'Tareas en segundo plano de iOS';

  @override
  String get backgroundOptimizationIosSupported =>
      'Esta versión de iOS (26 o posterior) admite tareas en segundo plano en curso. Las tareas generalmente continúan cuando cambias de aplicación o bloqueas la pantalla, aunque el sistema puede detenerlas cuando los recursos son bajos. Puedes ver el progreso en la pantalla de bloqueo.';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'Esta versión de iOS (anterior a la 26) no admite tareas en segundo plano en curso. Mientras se ejecuta una tarea, regrese a la aplicación cada pocos minutos (aproximadamente cada 5 a 10 minutos; el tiempo depende de iOS) para actualizar su tiempo de fondo y evitar la suspensión.';

  @override
  String get backgroundOptimizationIosWarning =>
      'En todas las versiones de iOS, no deslices Stroom en el selector de aplicaciones. Al hacerlo, se detendrán inmediatamente todas las tareas en ejecución.';

  @override
  String get backgroundOptimizationDesktopIntro =>
      'Los sistemas de escritorio no tienen el mecanismo de mantenimiento de procesos de las plataformas móviles, pero la aplicación puede continuar ejecutándose después de que se cierra la ventana.';

  @override
  String get backgroundOptimizationCloseMinimizeTitle =>
      'Minimizar al cerrar la ventana';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      'Cuando está habilitado, al hacer clic en el botón de cerrar de la ventana se oculta la aplicación en la bandeja del sistema en lugar de salir. Las tareas en segundo plano continúan ejecutándose.\n\nRestaure la ventana desde el icono de la bandeja o su elemento de menú \"Mostrar ventana principal\". Para salir, utilice el botón \"Salir de la aplicación\" que aparece a continuación.\n\nRecomendado para todos los usuarios de escritorio.';

  @override
  String get backgroundOptimizationQuitApp => 'Salir de la aplicación';

  @override
  String get backgroundOptimizationGotIt => 'Entiendo';

  @override
  String get backgroundOptimizationWebNoteTitle =>
      'Tareas web en segundo plano';

  @override
  String get backgroundOptimizationWebNote =>
      'Los navegadores no pueden mantener las aplicaciones ejecutándose en segundo plano. Al cerrar o actualizar esta pestaña, o si el navegador congela una pestaña en segundo plano inactiva, se detiene inmediatamente la ejecución de tareas. Mantenga la pestaña Stroom abierta y en primer plano mientras se ejecutan las tareas.';

  @override
  String get backgroundOptimizationTutorial => 'Guías de plataforma';

  @override
  String get backgroundOptimizationTutorialDescription =>
      'Ver guías de optimización en segundo plano para cada plataforma';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      'Comprobando el estado del servicio en segundo plano...';

  @override
  String get backgroundOptimizationServiceUnknown =>
      'Se desconoce el estado del servicio en segundo plano. Verifique nuevamente para confirmar si el servicio se está ejecutando.';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      'El servicio en segundo plano se está ejecutando. Las tareas pueden continuar en segundo plano.';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'Los servicios en segundo plano no son compatibles con los navegadores web. Mantenga esta página abierta para continuar con las tareas.';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      'La bandeja del escritorio no está disponible (las compilaciones de Linux requieren libayatana-appindicator3-dev). Al cerrar la ventana se saldrá de la aplicación.';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      'La bandeja del escritorio no está disponible. Al cerrar la ventana se saldrá de la aplicación.';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      'La aplicación está configurada para salir cuando se cierra la ventana del escritorio. Seguirá el flujo de confirmación de salida existente y no continuará ejecutándose en la bandeja.';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      'La bandeja del escritorio está habilitada. Al cerrar la ventana, se oculta la aplicación en la bandeja del sistema, donde continúa ejecutándose. Seleccione \"Mostrar ventana principal\" en el menú de la bandeja para restaurarla. Para salir por completo, seleccione \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      'La bandeja del escritorio está habilitada. Cerrar la ventana minimiza la aplicación en la bandeja del sistema, donde continúa ejecutándose. Haga clic en el icono de la bandeja o seleccione \"Mostrar ventana principal\" en su menú para restaurar la ventana. Para salir por completo, seleccione \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      'El servicio en segundo plano no se está ejecutando. Seleccione \"Iniciar servicio\" a continuación o consulte las guías de la plataforma para aprender cómo optimizar la actividad en segundo plano.';

  @override
  String get notificationSettingsPageTitle =>
      'Configuración de permisos de notificación';

  @override
  String get notificationSettingsWebUnsupported =>
      'Las notificaciones no son compatibles con los navegadores web.';

  @override
  String get notificationSettingsChecking => 'De cheques…';

  @override
  String get notificationSettingsPermissionGranted =>
      'Permiso de notificación concedido';

  @override
  String get notificationSettingsPermissionDenied =>
      'Permiso de notificación no concedido';

  @override
  String get notificationSettingsPermissionRestricted =>
      'Permiso de notificación restringido';

  @override
  String get notificationSettingsPermissionBlocked =>
      'Permiso de notificación bloqueado permanentemente';

  @override
  String get notificationSettingsPermissionProvisional =>
      'Permiso de notificación provisional';

  @override
  String get notificationSettingsWebGuide =>
      'Las notificaciones del sistema no son compatibles con los navegadores web.';

  @override
  String get notificationSettingsCheckingPermission =>
      'Comprobando el permiso de notificación...';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      'Se concede el permiso de notificación. Puede habilitar las notificaciones de finalización de tareas para recibir alertas del sistema cuando una tarea se completa o falla.';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      'No se ha concedido el permiso de notificación. Seleccione el botón a continuación para solicitar permiso o habilitar notificaciones para Stroom en la configuración del sistema.';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      'El permiso de notificación está restringido por el sistema, por ejemplo mediante controles parentales. Verifique la configuración de notificaciones de Stroom en la configuración del sistema.';

  @override
  String get notificationSettingsEnvironment => 'Entorno del sistema';

  @override
  String get notificationSettingsPermissionSection => 'Permiso de notificación';

  @override
  String get notificationSettingsPlatformGuides => 'Guía de plataforma';

  @override
  String get notificationSettingsGuideIntro =>
      'Siga estos pasos para que su sistema operativo habilite las notificaciones de Stroom.';

  @override
  String get notificationSettingsTaskCompleteTitle =>
      'Notificaciones de finalización de tareas';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      'Enviar una notificación cuando una tarea se complete o falle';

  @override
  String get notificationSettingsCheckAgain => 'Comprobar de nuevo';

  @override
  String get notificationSettingsOpenSystemSettings =>
      'Abrir configuración del sistema';

  @override
  String get notificationSettingsRequestPermission => 'Solicitar permiso';

  @override
  String get notificationSettingsGuideUnsupported =>
      'Las guías de configuración de notificaciones no están disponibles para esta plataforma.';

  @override
  String get notificationSettingsUsageReason =>
      'Para enviar notificaciones cuando se completen las tareas';

  @override
  String get notificationSettingsAndroidEnableTitle =>
      'Habilitar notificaciones';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      'Vaya a Configuración → Aplicaciones → Stroom → Gestión de notificaciones y permita notificaciones. Si no puede encontrar Stroom, asegúrese de que esté instalado. Si las notificaciones están deshabilitadas, actívelas.';

  @override
  String get notificationSettingsAndroidDndTitle => 'Marque No molestar';

  @override
  String get notificationSettingsAndroidDndDescription =>
      'Vaya a Configuración → Sonido y vibración → No molestar. Asegúrate de que esté apagado o que las notificaciones de Stroom estén permitidas.';

  @override
  String get notificationSettingsAndroidPopupTitle =>
      'Permitir que aparezcan notificaciones emergentes';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'Algunos sistemas Android, como MIUI, EMUI y ColorOS, requieren que \"Permitir notificaciones\" y \"Permitir ventanas emergentes\" estén habilitados en Información de la aplicación. También considere desactivar el “Filtrado de notificaciones” o las “Notificaciones inteligentes” para la aplicación.';

  @override
  String get notificationSettingsReturnTitle => 'Regresar a esta página';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      'Después de cambiar esta configuración, seleccione \"Verificar nuevamente\" para confirmar el estado del permiso. Cuando se concede el permiso, puede habilitar las notificaciones de finalización de tareas.';

  @override
  String get notificationSettingsIosEnableDescription =>
      'Vaya a Configuración → Notificaciones → Stroom y active “Permitir notificaciones”. También habilite los banners y el centro de notificaciones para mantenerse actualizado sobre el estado de las tareas.';

  @override
  String get notificationSettingsIosFocusTitle => 'Desactivar el enfoque';

  @override
  String get notificationSettingsIosFocusDescription =>
      'Vaya a Configuración → Enfoque. Asegúrate de que Focus esté desactivado o agrega Stroom a la lista de aplicaciones permitidas. Focus puede silenciar las notificaciones de aplicaciones.';

  @override
  String get notificationSettingsIosReturnDescription =>
      'Después de cambiar esta configuración, seleccione \"Verificar nuevamente\" para confirmar el estado del permiso. En iOS, el permiso de notificación generalmente debe habilitarse manualmente en la configuración del sistema.';

  @override
  String get notificationSettingsWindowsEnableTitle =>
      'Habilitar notificaciones del sistema';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      'Vaya a Configuración → Sistema → Notificaciones y acciones y active \"Recibir notificaciones de aplicaciones y otros remitentes\". Busque Stroom en la lista de aplicaciones a continuación y asegúrese de que sus notificaciones estén activadas.';

  @override
  String get notificationSettingsWindowsFocusTitle =>
      'Agregar una excepción de asistencia de enfoque';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      'Vaya a Configuración → Sistema → Asistente de enfoque. Agregue Stroom a \"Solo prioridad\" o desactive Focus Assist; Focus Assist puede silenciar las notificaciones.';

  @override
  String get notificationSettingsMacEnableTitle => 'Habilitar notificaciones';

  @override
  String get notificationSettingsMacEnableDescription =>
      'Vaya a Configuración del sistema → Notificaciones → Stroom y active “Permitir notificaciones”. Habilite también los banners y el centro de notificaciones.';

  @override
  String get notificationSettingsMacFocusDescription =>
      'Vaya a Configuración del sistema → Enfoque. Asegúrate de que Focus esté desactivado o agrega Stroom a la lista de aplicaciones permitidas.';

  @override
  String get notificationSettingsLinuxDesktopTitle =>
      'Verifique la configuración de notificaciones de escritorio';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      'Dependiendo de su entorno de escritorio (GNOME, KDE, XFCE, etc.), vaya a Configuración del sistema → Notificaciones, busque Stroom y asegúrese de que las notificaciones estén activadas.';

  @override
  String get notificationSettingsLinuxDaemonTitle =>
      'Verifique el demonio de notificación';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Los entornos de escritorio Linux necesitan un demonio de notificación, como notify-osd o dunst, para mostrar las notificaciones del sistema. Asegúrese de que uno esté instalado y ejecutándose.';

  @override
  String get backupRestorePageTitle => 'Copia de seguridad y restauración';

  @override
  String get backupRestoreSelectBackupCategory =>
      'Seleccione al menos una categoría de datos para realizar una copia de seguridad';

  @override
  String get backupRestorePreparingData => 'Preparando datos…';

  @override
  String get backupRestoreExportingBackup => 'Exportando copia de seguridad';

  @override
  String get backupRestoreCollectingDatabase =>
      'Recopilando registros de bases de datos...';

  @override
  String get backupRestoreProcessingSettings =>
      'Configuración de procesamiento…';

  @override
  String get backupRestoreAddingTasks => 'Agregando archivos de tareas…';

  @override
  String get backupRestoreAddingPictures => 'Agregando archivos de imagen…';

  @override
  String get backupRestoreAddingAudio => 'Agregando archivos de audio…';

  @override
  String get backupRestoreAddingVideo => 'Agregando archivos de vídeo…';

  @override
  String get backupRestoreAddingText => 'Agregando archivos de texto…';

  @override
  String get backupRestoreAddingChat =>
      'Agregando historial de chat y archivos adjuntos...';

  @override
  String get backupRestoreCompressing => 'Comprimiendo archivo…';

  @override
  String get backupRestoreCompleted => 'Completo';

  @override
  String get backupRestoreSelectRestoreCategory =>
      'Seleccione al menos una categoría de datos para restaurar';

  @override
  String get backupRestoreConfirmRestore => 'Confirmar restauración';

  @override
  String get backupRestoreSelectedCategories =>
      'Categorías de datos seleccionadas:';

  @override
  String get backupRestoreRestoreInfo =>
      'Las categorías seleccionadas que se encuentren en la copia de seguridad se restaurarán en este dispositivo. Todas las categorías, excepto las cookies integradas en el navegador, reemplazan los datos locales correspondientes. Las cookies se escriben por dominio, nombre y ruta; Se conservan las cookies locales no incluidas en la copia de seguridad. Las categorías no seleccionadas y las categorías que faltan en la copia de seguridad permanecen sin cambios. Las categorías que faltan se omiten con un aviso.';

  @override
  String get backupRestoreRestartNotice =>
      'Reinicie la aplicación después de restaurarla para que los cambios surtan efecto. Asegúrese de que su trabajo actual esté guardado.';

  @override
  String get backupRestoreCancel => 'Cancelar';

  @override
  String get backupRestoreConfirmRestoreButton => 'Restaurar';

  @override
  String get backupRestoreIncompleteTitle => 'Restaurar incompleto';

  @override
  String get backupRestoreIncompleteMessage =>
      'Los datos no se pudieron restaurar completamente y es posible que algunos datos se hayan borrado. Reinicie la aplicación y vuelva a intentarlo.';

  @override
  String get backupRestoreSelectClearCategory =>
      'Seleccione al menos una categoría de datos para borrar';

  @override
  String get backupRestoreClearingData => 'Borrar datos';

  @override
  String get backupRestoreDeletingCategories =>
      'Eliminando categorías de datos seleccionadas...';

  @override
  String get backupRestoreClearedTitle => 'Datos borrados';

  @override
  String get backupRestorePartiallyClearedTitle => 'Algunos datos borrados';

  @override
  String get backupRestoreClearedMessage =>
      'Se borraron los datos seleccionados. Reinicie la aplicación para que los cambios surtan efecto.';

  @override
  String get backupRestorePartialClearMessage =>
      'Se borraron otros datos seleccionados. Esta plataforma no puede borrar completamente el almacenamiento integrado del sitio web del navegador (localStorage, IndexedDB, etc.), por lo que los datos del navegador que no se pudieron borrar permanecen. Reinicie la aplicación para que los datos borrados surtan efecto.';

  @override
  String backupRestoreClearFailed(String error) {
    return 'No se pudieron borrar los datos: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => 'Borrar incompleto';

  @override
  String get backupRestoreClearIncompleteMessage =>
      'Algunos datos no se pudieron borrar. Reinicie la aplicación e intente borrarla nuevamente.';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Cubierta Anki exportada a: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get backupRestoreApkgRequired => 'Seleccione un archivo .apkg';

  @override
  String backupRestoreImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return 'Copia de seguridad guardada en: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return 'Error en la copia de seguridad: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return 'Error de restauración: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected =>
      'No se ha seleccionado ninguna carpeta de respaldo. Autorice uno durante el inicio.';

  @override
  String get backupRestoreRestoreSuccessTitle => 'Datos restaurados';

  @override
  String get backupRestoreRestoredMessage =>
      'Los datos fueron restaurados desde la copia de seguridad. Reinicie la aplicación para utilizar los datos restaurados.';

  @override
  String get backupRestoreExitApp => 'Salir de la aplicación';

  @override
  String get backupRestoreRestartNow => 'Reiniciar ahora';

  @override
  String get backupRestoreSkippedTitle => 'Algunos datos omitidos';

  @override
  String get backupRestoreNothingRestoredTitle => 'No se restauraron datos';

  @override
  String get backupRestoreGotIt => 'Entiendo';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return 'La copia de seguridad no confirmó el contenido restaurable para estas categorías seleccionadas, por lo que se omitieron y se conservaron los datos existentes: $categories.';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      'En copias de seguridad más antiguas, un archivo de tareas vacío no puede distinguir una lista de tareas vacía de tareas no exportadas por esa plataforma. Para evitar sobrescribir las tareas actuales, se omitió la categoría de tarea y se mantuvieron los datos existentes.';

  @override
  String get backupRestoreSkippedCookies =>
      'La copia de seguridad no contiene cookies integradas del navegador para importar, por lo que se omitió esta categoría y se mantuvieron las cookies existentes.';

  @override
  String get backupRestoreSkippedWebsiteData =>
      'Se omitió el directorio de almacenamiento del sitio web en esta copia de seguridad anterior. Las cookies aún se pueden importar por separado si el archivo las contiene y se selecciona esa categoría.';

  @override
  String get backupRestoreApkgTitle => 'Cubierta Anki';

  @override
  String get backupRestoreApkgInfoTitle =>
      'Importar o exportar una baraja Anki';

  @override
  String get backupRestoreApkgInfoMessage =>
      'Incluye información de la tarjeta únicamente, no medios';

  @override
  String get backupRestoreApkgDescription =>
      'Importa o exporta mazos de Anki en formato .apkg';

  @override
  String get backupRestoreExportingApkg => 'Exportador…';

  @override
  String get backupRestoreExportApkg => 'Exportar .apkg';

  @override
  String get backupRestoreImportingApkg => 'Importador…';

  @override
  String get backupRestoreImportApkg => 'Importar .apkg';

  @override
  String get backupRestoreCategoryHeading =>
      'Elija categorías de datos para realizar una copia de seguridad o restaurar';

  @override
  String get backupRestoreExporting => 'Exportador…';

  @override
  String get backupRestoreExportBackup => 'Exportar copia de seguridad';

  @override
  String get backupRestoreRestoring => 'Restaurando…';

  @override
  String get backupRestoreChooseBackup =>
      'Elija el archivo de copia de seguridad y restaure';

  @override
  String get backupRestoreClearSelected => 'Borrar datos seleccionados';

  @override
  String get backupRestoreClearDescription =>
      'Borre las categorías de datos seleccionadas directamente sin un archivo de respaldo. Las categorías no seleccionadas permanecerán sin cambios. Esta acción no se puede deshacer.';

  @override
  String get backupRestoreClearing => 'Borrando…';

  @override
  String get backupRestoreCategoryChat =>
      'Historial de chat y archivos adjuntos';

  @override
  String get backupRestoreCategoryChatDescription =>
      'Conversaciones de chat, contenido de mensajes y archivos adjuntos';

  @override
  String get backupRestoreCategorySettings => 'Ajustes';

  @override
  String get backupRestoreCategorySettingsDescription =>
      'Configuración de la aplicación, configuración del proveedor y preferencias de la interfaz';

  @override
  String get backupRestoreCategoryPictures => 'Imágenes';

  @override
  String get backupRestoreCategoryPicturesDescription => 'Fotos y miniaturas';

  @override
  String get backupRestoreCategoryAudio => 'Audio';

  @override
  String get backupRestoreCategoryAudioDescription =>
      'Síntesis de voz y grabaciones.';

  @override
  String get backupRestoreCategoryVideos => 'Vídeos';

  @override
  String get backupRestoreCategoryVideosDescription => 'Archivos de vídeo';

  @override
  String get backupRestoreCategoryTexts => 'Texto';

  @override
  String get backupRestoreCategoryTextsDescription => 'Documentos de texto';

  @override
  String get backupRestoreCategoryTasks => 'Tareas';

  @override
  String get backupRestoreCategoryTasksDescription =>
      'Registros de tareas en segundo plano';

  @override
  String get backupRestoreCategoryAnki =>
      'Datos de la tarjeta didáctica de Anki';

  @override
  String get backupRestoreCategoryAnkiDescription => 'base de datos anki';

  @override
  String get backupRestoreAnkiDataInfoTitle =>
      'Datos de la tarjeta didáctica de Anki';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Hacer una copia de seguridad o restaurar los datos de la tarjeta flash Anki también incluye los medios de la tarjeta en el directorio collection.media.';

  @override
  String get backupRestoreAnkiDataInfoTooltip =>
      'Acerca de los datos de Anki Flashcard';

  @override
  String get backupRestoreCategoryBrowser => 'Datos del navegador integrados';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      'Realiza copias de seguridad y restaura cookies únicamente; La limpieza también elimina el almacenamiento del sitio web compatible.';

  @override
  String get backupRestoreViewInfo => 'Ver información';

  @override
  String get backupRestoreApkgInfoTooltip =>
      'Acerca de la importación y exportación de Anki Deck';

  @override
  String get backupRestoreConfirmClear => 'Confirmar Borrar';

  @override
  String get backupRestoreClearCategoriesIntro =>
      'Las siguientes categorías de datos se borrarán sin utilizar un archivo de copia de seguridad:';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      'Esta plataforma no puede borrar completamente el almacenamiento del sitio web integrado del navegador (localStorage, IndexedDB, etc.). Al confirmar se borran los demás datos seleccionados; Los datos del navegador que no se puedan borrar permanecerán.';

  @override
  String get backupRestoreUnselectedUnchanged =>
      'Las categorías no seleccionadas permanecerán sin cambios.';

  @override
  String get backupRestoreClearWarning =>
      'Esta acción no se puede deshacer. Reinicie la aplicación después de borrarla para que los cambios surtan efecto.';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return 'Borrar ($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment =>
      'Entorno del navegador';

  @override
  String get backupRestoreIntro =>
      'Exporte las categorías de datos seleccionadas manualmente. Durante la importación, solo se restauran las categorías seleccionadas que se encuentran en el archivo. Una categoría faltante o un archivo requerido se omite con un aviso y las categorías no seleccionadas permanecen sin cambios. También puede borrar las categorías seleccionadas directamente.';

  @override
  String get backupRestoreOtherSelectedRestored =>
      'Los demás datos seleccionados fueron restaurados. Reinicie la aplicación para que los cambios surtan efecto.';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      'Las notificaciones están bloqueadas. Abra la configuración del sistema y permita notificaciones para Stroom.';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      'Las notificaciones están bloqueadas. Vaya a Configuración del sistema → Aplicaciones → Stroom → Gestión de notificaciones y permita notificaciones.';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      'Las notificaciones están bloqueadas. Vaya a Configuración del sistema → Stroom → Notificaciones y permita notificaciones.';

  @override
  String get textPreviewDiscardEditsTitle => '¿Descartar ediciones?';

  @override
  String get textPreviewUnsavedChangesConfirm =>
      'Tienes cambios sin guardar. ¿Estás seguro de que quieres descartarlos?';

  @override
  String get textPreviewCancel => 'Cancelar';

  @override
  String get textPreviewDiscard => 'Desechar';

  @override
  String get textPreviewFontSize => 'Ajustar el tamaño de fuente';

  @override
  String get textPreviewRestoreDefault => 'Restaurar valor predeterminado';

  @override
  String get textPreviewClose => 'Cerrar';

  @override
  String textPreviewSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get textPreviewUndo => 'Deshacer';

  @override
  String get textPreviewRedo => 'Rehacer';

  @override
  String get textPreviewSave => 'Guardar';

  @override
  String get textPreviewEdit => 'Editar';

  @override
  String get textPreviewChartEdit => 'Editar gráfico';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return 'Formato no compatible omitido: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# archivos de texto',
      one: '# archivo de texto',
    );
    return 'Se importó $_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String get textStorageSaved => 'Texto guardado';

  @override
  String get textStorageLoadFailed => 'No se puede cargar contenido de texto';

  @override
  String get textStorageReadFailed =>
      'No se pudieron leer los datos del archivo';

  @override
  String get textStorageExportTitle => 'Exportar texto';

  @override
  String textStorageExportedTo(String path) {
    return 'Exportado a: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get textStorageChooseExportDirectory =>
      'Elija el directorio de exportación';

  @override
  String get textStorageFolderExportTitle => 'Exportar carpeta';

  @override
  String get textStorageWebFolderExportInfo =>
      'El navegador no puede seleccionar un directorio de exportación. Se descargará un archivo ZIP que conserva la estructura de carpetas.';

  @override
  String get textStorageCancel => 'Cancelar';

  @override
  String get textStorageDownloadZip => 'Descargar archivo ZIP';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# archivos',
      one: '# archivo',
    );
    return 'Se exportó $_temp0';
  }

  @override
  String get textStorageExportFolderTitle => 'Exportar carpeta de texto';

  @override
  String textStorageCopyFailed(String error) {
    return 'Copia fallida: $error';
  }

  @override
  String get textStorageCreateNew => 'Nuevo';

  @override
  String get textStorageImport => 'Importar';

  @override
  String get textStorageTitle => 'Texto';

  @override
  String get textStorageExportToLocal => 'Exportar a local';

  @override
  String get textCreateEnterTitle => 'Por favor introduce un título';

  @override
  String textCreateSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get textCreateNewTitle => 'Nuevo';

  @override
  String get textCreateSave => 'Guardar';

  @override
  String get textCreateTitleLabel => 'Título';

  @override
  String get textCreateTitleHint => 'Introduzca el título del texto';

  @override
  String get textCreateFormatLabel => 'Formato';

  @override
  String get textCreateContentLabel => 'Contenido del texto';

  @override
  String get textCreateContentHint => 'Introduzca el contenido del texto...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return 'Tutorial de optimización en segundo plano $platform';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return 'Guía de ejecución en segundo plano $platform';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return 'Guía de optimización en segundo plano $platform';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return 'Estos pasos pueden ayudar a optimizar la experiencia en segundo plano de Stroom en dispositivos $platform para que las tareas puedan continuar ejecutándose en segundo plano.';
  }

  @override
  String get platformTutorialStepsHeading => 'Pasos de optimización';

  @override
  String get platformTutorialTipsHeading => 'Consejo';

  @override
  String get platformTutorialTipsDescription =>
      'Después de completar esta configuración, regrese a la página \"Optimización de fondo\" y verifique que el estado se haya actualizado. Si aún tiene problemas, consulte la guía de otra plataforma o informe el problema en GitHub.';

  @override
  String get platformTutorialAndroidStep1Title =>
      'Desactivar la optimización de la batería';

  @override
  String get platformTutorialAndroidStep1Description =>
      'Abra Configuración → Aplicaciones → Stroom → Batería, luego elija “Sin restricciones” o “No optimizar”. También puede tocar \"Ignorar optimización de la batería\" en la página \"Optimización en segundo plano\" de esta aplicación para agregar Stroom a la lista de permitidos de ahorro de energía del sistema. Las rutas varían según la marca del dispositivo.';

  @override
  String get platformTutorialAndroidStep2Title =>
      'Permitir actividad en segundo plano';

  @override
  String get platformTutorialAndroidStep2Description =>
      'Abra Configuración → Aplicaciones → Stroom y habilite “Permitir actividad en segundo plano” y “Permitir inicio automático”. Algunos teléfonos también requieren permitir el inicio automático en Security Center o Phone Manager.';

  @override
  String get platformTutorialAndroidStep3Title =>
      'Bloquear el proceso en segundo plano';

  @override
  String get platformTutorialAndroidStep3Description =>
      'En la vista de aplicaciones recientes, deslice hacia abajo la tarjeta Stroom o toque su ícono de candado para evitar que el sistema borre la aplicación.';

  @override
  String get platformTutorialAndroidStep4Title =>
      'Permitir notificaciones (Android 13+)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 y versiones posteriores requieren permiso de notificación. Sin él, la notificación en primer plano para el servicio en segundo plano está oculta, aunque el servicio aún se ejecuta. La aplicación solicita permiso cuando tocas por primera vez \"Iniciar servicio\", o puedes habilitarlo en Configuración → Aplicaciones → Stroom → Notificaciones.';

  @override
  String get platformTutorialAndroidStep5Title =>
      'Ignorar la optimización de la batería';

  @override
  String get platformTutorialAndroidStep5Description =>
      'Cuando habilitas las “Notificaciones de finalización de tareas” en Stroom, la aplicación solicita el permiso relacionado. También puede verificar que Stroom esté configurado en \"No optimizar\" en Configuración → Aplicaciones → Acceso a aplicaciones especiales → Optimización de la batería.';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Inicio automático y gestión en segundo plano en dispositivos Android';

  @override
  String get platformTutorialAndroidStep6Description =>
      'Los fabricantes de dispositivos suelen añadir sus propios controles en segundo plano:\n• Xiaomi/Redmi (MIUI/HyperOS): Configuración → Aplicaciones → Permisos → Inicio automático; permitir Stroom. Luego abra Batería → Ahorro de batería de la aplicación → Stroom → Sin restricciones.\n• Huawei/Honor (EMUI/HarmonyOS): Configuración → Aplicaciones → Inicio de aplicación → Stroom → Administrar manualmente; permitir el inicio automático, el inicio secundario y la actividad en segundo plano.\n• OPPO/OnePlus/realme (ColorOS): Configuración → Batería → Gestión de batería de la aplicación → Stroom; permitir actividad en segundo plano completa.\n• vivo/iQOO (OriginOS): iManager → Gestión de aplicaciones → Inicio automático; permitir Stroom.';

  @override
  String get platformTutorialAndroidStep7Title =>
      'Desactivar la limpieza de la pantalla de bloqueo y los modos de ahorro de energía';

  @override
  String get platformTutorialAndroidStep7Description =>
      'Abra Configuración → Batería y desactive \"Ahorro de energía\" o \"Ultra ahorro de energía\". También configure \"Borrar memoria después de bloquear\" en \"No borrar\". Los modos de ahorro de energía restringen la actividad en segundo plano y pueden afectar la finalización de la tarea.';

  @override
  String get platformTutorialIosStep1Title =>
      'Habilitar actualización de la aplicación en segundo plano';

  @override
  String get platformTutorialIosStep1Description =>
      'Abra Configuración → General → Actualización de la aplicación en segundo plano, busque Stroom y actívelo. Elija \"Wi-Fi y datos móviles\" para disfrutar de la mejor experiencia.';

  @override
  String get platformTutorialIosStep2Title => 'Permitir notificaciones';

  @override
  String get platformTutorialIosStep2Description =>
      'Abra Configuración → Notificaciones → Stroom y active “Permitir notificaciones”. Habilite los banners y el Centro de notificaciones para que pueda ver las actualizaciones de tareas rápidamente.';

  @override
  String get platformTutorialIosStep3Title =>
      'Desactivar el modo de bajo consumo';

  @override
  String get platformTutorialIosStep3Description =>
      'Abra Configuración → Batería y desactive el \"Modo de bajo consumo\". El sistema restringe la actividad en segundo plano mientras este modo está activado.';

  @override
  String get platformTutorialIosStep4Title =>
      'Comprender los límites de fondo de iOS';

  @override
  String get platformTutorialIosStep4Description =>
      'Las versiones anteriores a iOS 26 no permiten que las aplicaciones permanezcan en segundo plano como las aplicaciones de Android. El sistema proporciona a las aplicaciones un breve tiempo de ejecución solo en determinados momentos, como la actualización de la aplicación en segundo plano, las actualizaciones de ubicación o la reproducción de audio, y puede suspender tareas de ejecución prolongada. Recomendamos:\n• Mantenga Stroom en primer plano para tareas de larga duración.\n• Regrese a la aplicación periódicamente para actualizar su tiempo de fondo.\n• Active \"Notificaciones de finalización de tareas\" para tareas importantes.';

  @override
  String get platformTutorialIosStep5Title =>
      'Consejos en segundo plano mientras se ejecutan las tareas';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 y versiones posteriores admiten tareas persistentes en segundo plano. Las tareas generalmente continúan si cambias de aplicación o bloqueas la pantalla, aunque el sistema puede detenerlas cuando los recursos son escasos; El progreso aparece en la pantalla de bloqueo.\n\nLas versiones anteriores de iOS no admiten tareas persistentes en segundo plano. Regrese a la aplicación cada pocos minutos (5 a 10 minutos es una pauta; el sistema decide) para actualizar el tiempo en segundo plano y evitar la suspensión.\n\nEn todas las versiones, no deslices Stroom en el selector de aplicaciones; Al hacerlo, se detendrán inmediatamente todas las tareas en ejecución.';

  @override
  String get platformTutorialIosStep6Title =>
      'Mantenga la aplicación en primer plano';

  @override
  String get platformTutorialIosStep6Description =>
      'En versiones anteriores a iOS 26, las aplicaciones tienen un tiempo de fondo limitado. Para tareas de larga duración, mantenga Stroom en primer plano o vuelva a él periódicamente para extender ese tiempo.';

  @override
  String get platformTutorialWindowsStep1Title =>
      'Minimizar al cerrar la ventana.';

  @override
  String get platformTutorialWindowsStep1Description =>
      'De forma predeterminada, hacer clic en el botón de cerrar de la ventana minimiza Stroom en la bandeja del sistema (cerca del reloj) para que pueda seguir ejecutándose. Restaurarlo desde el icono de la bandeja o el menú \"Mostrar ventana principal\". No salga mientras se ejecutan las tareas. Para salir, use \"Salir de la aplicación por completo\" en la página \"Optimización de fondo\" o elija \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get platformTutorialWindowsStep2Title =>
      'Desactivar el ahorro de batería';

  @override
  String get platformTutorialWindowsStep2Description =>
      'Abra Configuración → Sistema → Encendido y suspensión y desactive Ahorro de batería. Alternativamente, configúrelo para que se encienda solo cuando la batería caiga por debajo del nivel elegido.';

  @override
  String get platformTutorialWindowsStep3Title =>
      'Permitir aplicaciones en segundo plano';

  @override
  String get platformTutorialWindowsStep3Description =>
      'Abra Configuración → Privacidad y seguridad → Aplicaciones en segundo plano, busque Stroom y asegúrese de que esté habilitado. En Windows 11, vaya a Configuración → Aplicaciones → Aplicaciones instaladas → Stroom → Opciones avanzadas → Permisos de aplicaciones en segundo plano y elija “Siempre”.';

  @override
  String get platformTutorialWindowsStep4Title =>
      'Desactivar el modo de suspensión (opcional)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'Para mantener Stroom funcionando durante períodos prolongados, abra Configuración → Sistema → Encendido y configure “Suspender” en “Nunca” (solo cuando esté enchufado).';

  @override
  String get platformTutorialWindowsStep5Title => 'Agregar Stroom al inicio';

  @override
  String get platformTutorialWindowsStep5Description =>
      'Abra el Administrador de tareas (Ctrl+Shift+Esc) → Inicio, busque Stroom y haga clic derecho en \"Activar\". O abra Configuración → Aplicaciones → Inicio y active Stroom.';

  @override
  String get platformTutorialMacosStep1Title =>
      'Minimizar al cerrar la ventana.';

  @override
  String get platformTutorialMacosStep1Description =>
      'De forma predeterminada, cerrar la ventana mantiene Stroom ejecutándose en la barra de menú (arriba a la derecha de la pantalla). Haga clic en el icono de la barra de menú o elija \"Mostrar ventana principal\" para restaurarlo. No salga mientras se ejecutan las tareas. Para salir, use \"Salir de la aplicación por completo\" en la página \"Optimización de fondo\" o elija \"Salir de Stroom\" en el menú de la barra de menú.';

  @override
  String get platformTutorialMacosStep2Title => 'Permitir notificaciones';

  @override
  String get platformTutorialMacosStep2Description =>
      'Abra Configuración del sistema → Notificaciones → Stroom y active “Permitir notificaciones”. Recomendamos habilitar tanto los banners como el Centro de notificaciones.';

  @override
  String get platformTutorialMacosStep3Title =>
      'Desactivar el modo de bajo consumo (MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      'Abra Configuración del sistema → Batería → Adaptador de corriente y desactive el “Modo de bajo consumo”. Este modo restringe la actividad en segundo plano.';

  @override
  String get platformTutorialMacosStep4Title => 'Mantén la aplicación activa';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS impone pocas restricciones a las aplicaciones en segundo plano. Para tareas de larga duración, deje abierta la ventana de Stroom. Evite el cierre forzado de la aplicación; cerrar la ventana es suficiente.';

  @override
  String get platformTutorialMacosStep5Title =>
      'Iniciar al iniciar sesión (opcional)';

  @override
  String get platformTutorialMacosStep5Description =>
      'Abra Configuración del sistema → General → Elementos de inicio de sesión y agregue Stroom para que se inicie automáticamente cuando se inicie su computadora.';

  @override
  String get platformTutorialLinuxStep1Title =>
      'Minimizar al cerrar la ventana.';

  @override
  String get platformTutorialLinuxStep1Description =>
      'De forma predeterminada, cerrar la ventana oculta Stroom en la bandeja del sistema (requiere un entorno de escritorio con soporte StatusNotifierItem y libayatana-appindicator3-dev en el momento de la compilación). Restaurarlo desde el menú de la bandeja usando \"Mostrar ventana principal\". No salga mientras se ejecutan las tareas. Para salir, use \"Salir de la aplicación por completo\" en la página \"Optimización de fondo\" o elija \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get platformTutorialLinuxStep2Title =>
      'Configuración del entorno de escritorio';

  @override
  String get platformTutorialLinuxStep2Description =>
      'Dependiendo de su entorno de escritorio (GNOME, KDE, XFCE, etc.), abra Configuración del sistema → Aplicaciones, busque Stroom y asegúrese de que la actividad en segundo plano no esté restringida.';

  @override
  String get platformTutorialLinuxStep3Title =>
      'Utilice un servicio systemd (opcional)';

  @override
  String get platformTutorialLinuxStep3Description =>
      'Para un trabajo en segundo plano de larga duración, cree un servicio de usuario systemd. Cree un archivo stroom.service en ~/.config/systemd/user/ y configure ExecStart como el ejecutable de Stroom.';

  @override
  String get platformTutorialLinuxStep4Title => 'Desactivar el sueño';

  @override
  String get platformTutorialLinuxStep4Description =>
      'Para un servidor o escritorio que necesita funcionar durante mucho tiempo, configure HandleLidSwitch=ignore en /etc/systemd/logind.conf para evitar el modo de suspensión cuando se cierra la tapa.';

  @override
  String get platformTutorialLinuxStep5Title => 'Habilitar inicio automático';

  @override
  String get platformTutorialLinuxStep5Description =>
      'En GNOME, use Ajustes → Aplicaciones de inicio → Agregar Stroom. O cree un archivo stroom.desktop en ~/.config/autostart/.';

  @override
  String get platformTutorialWebStep1Title => 'Mantenga la pestaña abierta';

  @override
  String get platformTutorialWebStep1Description =>
      'Los navegadores web no admiten servicios en segundo plano. Mantenga abierta la pestaña Stroom mientras se ejecutan las tareas; cerrar la pestaña o actualizar la página los interrumpe inmediatamente.';

  @override
  String get platformTutorialWebStep2Title =>
      'Evitar que el navegador suspenda la pestaña';

  @override
  String get platformTutorialWebStep2Description =>
      'Los navegadores pueden congelar pestañas en segundo plano inactivas para ahorrar recursos. Mantenga la pestaña Stroom en primer plano mientras se ejecutan las tareas o interactúe con la página periódicamente para mantenerla activa.';

  @override
  String get browserNavigationFailed =>
      'Falló la navegación de la página; dirección restaurada';

  @override
  String get browserAddressHint => 'Introduzca una dirección web';

  @override
  String get browserUserScripts => 'Guiones de usuario';

  @override
  String get browserSwitchToMobile => 'Cambiar a vista móvil';

  @override
  String get browserSwitchToDesktop => 'Cambiar a la vista de escritorio';

  @override
  String get browserUaSwitchedDesktop =>
      'Cambiado al agente de usuario de escritorio';

  @override
  String get browserUaSwitchedMobile => 'Cambiado al agente de usuario móvil';

  @override
  String get browserCookieRetentionOnTooltip =>
      'Persistencia de cookies (activada)';

  @override
  String get browserCookieRetentionOffTooltip =>
      'Persistencia de cookies (desactivada)';

  @override
  String get browserCookiePersistenceEnabled =>
      'Persistencia de cookies habilitada';

  @override
  String get browserCookiePersistenceDisabled =>
      'Persistencia de cookies deshabilitada';

  @override
  String get browserSniffPanelHideTooltip => 'Ocultar panel de rastreo';

  @override
  String get browserSniffPanelShowTooltip => 'Mostrar panel de olfateo';

  @override
  String get browserAdd => 'Agregar';

  @override
  String get browserNoScripts =>
      'Aún no hay guiones. Toque \"Agregar\" para crear uno.';

  @override
  String get browserUnnamedScript => 'Guión sin título';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas coincidentes',
      one: '$count regla coincidente',
    );
    return '$_temp0';
  }

  @override
  String get browserScriptOriginManual => 'Agregado manualmente';

  @override
  String browserScriptVersion(Object version) {
    return '@versión $version';
  }

  @override
  String get browserScriptEnabled => 'Activado';

  @override
  String get browserScriptDisabled => 'Desactivado';

  @override
  String get browserScriptRuntimeError =>
      'Este script encontró un error de tiempo de ejecución. Comprueba su código y compatibilidad de páginas.';

  @override
  String get browserScriptDelete => 'Borrar';

  @override
  String get browserDeleteScriptTitle => '¿Eliminar guión?';

  @override
  String get browserDeleteScriptConfirmation =>
      'Este script se eliminará de este navegador. Esta acción no se puede deshacer.';

  @override
  String get browserEditScript => 'Editar guión';

  @override
  String get browserScriptName => 'Nombre del guión';

  @override
  String get browserScriptCode =>
      'Código de secuencia de comandos (JavaScript)';

  @override
  String get browserAddScriptMethod => 'Elija cómo agregar un script';

  @override
  String get browserImportFromUrl => 'Importar desde URL';

  @override
  String get browserEnterManually => 'Ingresar manualmente';

  @override
  String get browserScriptTrustWarningTitle =>
      'Importe sólo scripts en los que confíe';

  @override
  String get browserScriptTrustWarning =>
      'Agregue únicamente scripts en los que confíe o podrían filtrar datos. Los scripts pueden leer o modificar el contenido de la página web.';

  @override
  String get browserContinue => 'Continuar';

  @override
  String get browserManualUserscriptLabel => 'Guión de usuario de Tampermonkey';

  @override
  String get browserScriptImportUrl => 'URL del guión';

  @override
  String get browserScriptImportFetch => 'Obtener vista previa';

  @override
  String get browserScriptPreview => 'Vista previa del origen del script';

  @override
  String get browserScriptImportInvalidUrl => 'Ingrese una URL HTTPS válida.';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Utilice una URL Greasy Fork .user.js o una URL sin formato de GitHub.';

  @override
  String get browserScriptImportRedirectedUrl =>
      'La URL redirigida a una dirección no compatible o insegura.';

  @override
  String get browserScriptImportNotScript =>
      'La respuesta está vacía o no parece ser un script JavaScript.';

  @override
  String get browserScriptImportNetworkError =>
      'No se pudo recuperar el guión. Verifique la URL y su conexión.';

  @override
  String browserScriptImportHttpError(Object status) {
    return 'El servidor devolvió HTTP $status.';
  }

  @override
  String get browserCancel => 'Cancelar';

  @override
  String get browserSave => 'Guardar';

  @override
  String get browserCookiesConfirmClear => 'Confirmar compensación';

  @override
  String get browserCookiesConfirmClearAll =>
      '¿Borrar todas las cookies?\nEsta acción no se puede deshacer.';

  @override
  String get browserCookiesClear => 'Borrar cookies';

  @override
  String get browserCookiesCancel => 'Cancelar';

  @override
  String get browserCookiesClearedAll => 'Todas las cookies borradas';

  @override
  String get browserCookiesClearFailed =>
      'No se pudo borrar. Intentar otra vez.';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return 'Todas las cookies para $domain borradas';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '¿Borrar todas las cookies para $domain?';
  }

  @override
  String get browserCookiesPageTitle => 'Gestión de datos del navegador';

  @override
  String get browserCookiesRetentionTitle => 'Mantener las cookies al salir';

  @override
  String get browserCookiesRetentionOn =>
      'Habilitado: las cookies se conservan al salir';

  @override
  String get browserCookiesRetentionOff =>
      'Deshabilitado: las cookies se borran al salir';

  @override
  String get browserCookiesClearAllTitle => 'Borrar todas las cookies';

  @override
  String get browserCookiesClearAllDescription =>
      'Eliminar todas las cookies guardadas del sitio web';

  @override
  String get browserCookiesEmptyTitle => 'Sin datos persistentes';

  @override
  String get browserCookiesEmptyDescription =>
      'Utilice el navegador integrado y habilite la persistencia de cookies para ver los datos guardados aquí.';

  @override
  String browserCookiesStoredCount(Object count) {
    return 'Cookies almacenadas ($count)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cookies',
      one: '$count cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip =>
      'Borrar todas las cookies para este dominio';

  @override
  String get browserCookiesDeleteOneTooltip => 'Eliminar esta cookie';

  @override
  String get browserCookiesDeletedOne => 'Cookie eliminada';

  @override
  String get browserCookiesDeleteFailed =>
      'No se pudo eliminar. Intentar otra vez.';

  @override
  String get browserCookiesEmptyValue => '(valor vacío)';

  @override
  String get platformTutorialPageTitle => 'Tutoriales de plataforma';

  @override
  String get browserRecoveryOpenPage => 'Abrir página de recuperación';

  @override
  String galleryUnsupportedPreview(String format) {
    return 'La vista previa no es compatible con archivos .$format';
  }

  @override
  String galleryCameraFailed(String error) {
    return 'No se pudo tomar una foto: $error';
  }

  @override
  String get galleryPhotoSaved => 'Foto guardada';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return 'Formato no compatible omitido: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron # imágenes',
      one: 'Se importó # imagen',
    );
    return '$_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron # videos',
      one: 'Se importó # video',
    );
    return '$_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String get galleryFileReadFailed =>
      'No se pudieron leer los datos del archivo';

  @override
  String get galleryExportImageTitle => 'Exportar imagen';

  @override
  String get galleryExportVideoTitle => 'Exportar vídeo';

  @override
  String galleryExportedTo(String path) {
    return 'Exportado a: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get galleryChooseExportDirectory =>
      'Elija el directorio de exportación';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se exportaron # archivos',
      one: 'Se exportó # archivo',
    );
    return '$_temp0';
  }

  @override
  String get galleryFolderExportTitle => 'Exportar carpeta';

  @override
  String get galleryWebFolderExportInfo =>
      'El navegador no puede seleccionar un directorio de exportación. Se descargará un archivo ZIP que conserva la estructura de carpetas.';

  @override
  String get galleryDownloadZip => 'Descargar archivo ZIP';

  @override
  String get galleryExportImageFolderTitle => 'Exportar carpeta de imágenes';

  @override
  String get galleryExportVideoFolderTitle => 'Exportar carpeta de vídeo';

  @override
  String get galleryImagePageTitle => 'Galería';

  @override
  String get galleryVideoPageTitle => 'Vídeos';

  @override
  String get galleryTakePhoto => 'tomar foto';

  @override
  String get galleryRecordVideo => 'Registro';

  @override
  String get galleryImport => 'Importar';

  @override
  String get galleryExportToLocal => 'Exportar a local';

  @override
  String get galleryPlayVideo => 'Jugar';

  @override
  String galleryCopyFailed(String error) {
    return 'Copia fallida: $error';
  }

  @override
  String get galleryVideoSaved => 'Vídeo guardado';

  @override
  String galleryVideoRecordFailed(String error) {
    return 'Error de grabación: $error';
  }

  @override
  String get galleryVideoLoadFailed => 'No se pudo cargar el video';

  @override
  String get imageEditorSaveImageTitle => 'Salvar el imagen';

  @override
  String get imageEditorSaveImagePrompt => 'Elija cómo guardar la imagen:';

  @override
  String get imageEditorOverwrite => 'Exagerar';

  @override
  String get imageEditorSaveAs => 'Guardar como';

  @override
  String get imageEditorSavePhotoTitle => 'guardar foto';

  @override
  String get imageEditorSavePhotoPrompt => '¿Guardar esta foto?';

  @override
  String get imageEditorDiscard => 'Desechar';

  @override
  String get imageEditorDoneLoading => 'Generando imagen. Espere por favor…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return 'Edición rápida – $fileName';
  }

  @override
  String get imageEditorNotReady =>
      'El editor no está listo. Inténtelo de nuevo en un momento.';

  @override
  String imageEditorProcessingFailed(String error) {
    return 'No se pudo procesar la imagen: $error';
  }

  @override
  String get imageEditorLoadFailed => 'No se pudo cargar la imagen';

  @override
  String get imageEditorProcessing =>
      'Procesamiento de imagen. Espere por favor…';

  @override
  String get imageEditorRotateLeft => 'Girar a la izquierda';

  @override
  String get imageEditorRotateRight => 'Girar a la derecha';

  @override
  String get imageEditorFlip => 'Voltear';

  @override
  String get imageEditorCrop => 'Cultivo';

  @override
  String get imageViewerImageSavedAsCopy => 'Imagen guardada como copia';

  @override
  String get imageViewerImageUpdated => 'Imagen actualizada';

  @override
  String imageViewerSaveFailed(String error) {
    return 'No se pudo guardar la imagen: $error';
  }

  @override
  String get imageViewerInvalidIndex => 'Índice de imagen no válido';

  @override
  String get galleryExportImageArchiveFileName => 'exportar-imagen.zip';

  @override
  String get galleryExportVideoArchiveFileName => 'exportar-video.zip';

  @override
  String get galleryExportImageFolderArchiveFileName =>
      'carpeta-imagen-exportar.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName =>
      'carpeta-de-video-exportación.zip';

  @override
  String get catCatchPageTitle => 'Descargador de recursos web';

  @override
  String get catCatchAddTask => 'Agregar tarea';

  @override
  String get catCatchOpenBrowser => 'Navegador incorporado';

  @override
  String get catCatchEmptyState => 'Aún no hay tareas de descarga';

  @override
  String get catCatchEmptyStateHint =>
      'Toca + en la parte superior derecha para agregar una tarea de descarga';

  @override
  String get catCatchInvalidCapturedUrl => 'La URL capturada no es válida.';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return 'Capturado desde el navegador: $url';
  }

  @override
  String get catCatchEnterValidUrl => 'Introduce al menos una URL válida';

  @override
  String get catCatchTaskAdded => 'Tarea agregada';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas añadidas',
      one: '$count tarea añadida',
    );
    return '$_temp0';
  }

  @override
  String get catCatchViewTaskList => 'Ver lista de tareas';

  @override
  String get catCatchUrlHint =>
      'Ingrese la URL de una página web de video/audio';

  @override
  String get catCatchDeleteTask => 'Eliminar esta tarea';

  @override
  String get catCatchHour => 'Horas';

  @override
  String get catCatchMinute => 'Minutos';

  @override
  String get catCatchSecond => 'Artículos de segunda clase';

  @override
  String get catCatchDurationPreview => 'Avance:';

  @override
  String get catCatchDurationFormat => 'h:min:seg';

  @override
  String get catCatchDurationFilterHint =>
      'Opcional: filtre los recursos de vídeo por duración. Déjelo en blanco para mostrar todos los recursos para su selección.';

  @override
  String get catCatchVideoSaveTo => 'Guardar vídeo en';

  @override
  String get catCatchAudioSaveTo => 'Guardar audio en';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas añadidas',
      one: '$count tarea añadida',
    );
    return '$_temp0';
  }

  @override
  String get catCatchStartAnalysis => 'Analizar';

  @override
  String get catCatchVideoFolderTitle => 'Carpeta para guardar vídeos';

  @override
  String get catCatchAudioFolderTitle => 'Carpeta para guardar audio';

  @override
  String get catCatchRootFolder => 'Carpeta raíz';

  @override
  String connectivityTestTitle(String title) {
    return '$title · Prueba de conectividad';
  }

  @override
  String get connectivityTestJsonLabel => 'Contenido de prueba (JSON)';

  @override
  String get connectivityTestJsonHelp =>
      'Puede ejecutar o guardar los cambios directamente. MCP utiliza herramientas/listas de solo lectura; las herramientas de búsqueda pueden cambiar la consulta/el recuento; Todo es de sólo lectura de forma predeterminada.';

  @override
  String connectivityTestSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get connectivityTestSaved => 'Contenido de prueba guardado';

  @override
  String get connectivityTestClose => 'Cerrar';

  @override
  String get connectivityTestSaveContent => 'Guardar contenido';

  @override
  String get connectivityTestTesting => 'Pruebas…';

  @override
  String get connectivityTestRun => 'Ejecutar prueba';

  @override
  String get connectivityTestFailedSummary => 'No se pudo completar la prueba';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds seg.';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get messageSearchTitle => 'Buscar mensajes';

  @override
  String get messageSearchHint =>
      'Buscar mensajes en todas las conversaciones...';

  @override
  String get messageSearchInitialState =>
      'Escriba una palabra clave para buscar mensajes en todas las conversaciones.';

  @override
  String get messageSearchEmptyState =>
      'No se encontraron mensajes coincidentes';

  @override
  String get messageSearchNewConversation => 'Nueva conversación';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coincidencias',
      one: '$count coincidencia',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => 'Texto';

  @override
  String get filesTabAudio => 'Audio';

  @override
  String get filesTabImages => 'Imágenes';

  @override
  String get filesTabVideos => 'Vídeos';

  @override
  String get filesReorderTabs => 'Reordenar pestañas';

  @override
  String get filesReorderCancel => 'Cancelar';

  @override
  String get filesReorderDone => 'Hecho';

  @override
  String get bgTaskCancelled => 'Cancelado';

  @override
  String bgTaskAsrError(String details) {
    return 'Error en la transcripción de voz: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return 'Error al guardar la transcripción de voz: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'Error de OCR: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'Error al guardar los resultados de OCR: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'El resultado del OCR está incompleto: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback =>
      'Algunas páginas de OCR no se completaron';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return '· fase $phaseElapsedMs ms · solicitudes $completedRequests · fragmentos $completedChunks/$chunkCount completados';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return 'Subiendo audio$chunk $percent% · $bytes bytes$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return 'Subiendo audio$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return '(fragmento $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return 'Transcribiendo$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return 'Transcripción (fragmento $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return 'Transcribiendo (recibiendo fragmento $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return 'Recibiendo resultado $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => 'Recibiendo resultado';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return 'Transcripción (fragmentos $index/$count completados)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return 'Transcripción (fragmento $index/$count devuelto)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return 'Imagen $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return 'Subiendo $details';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return 'Subiendo imágenes $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'No se pudo guardar el punto de control de recuperación de ASR; el resultado de la solicitud es incierto y la tarea se detuvo: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'No se pudo guardar el punto de control de recuperación de ASR; este fragmento no se envió y se puede volver a intentar después de arreglar el almacenamiento local: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'El estado del fragmento ASR no se pudo guardar antes de la cancelación; El resultado de este fragmento sigue siendo incierto: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'No se pudo guardar el audio del reintento de ASR; la tarea no fue enviada: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError =>
      'No se pudo guardar otro archivo de audio; el envío fue cancelado';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'El OCR devolvió un resultado incompleto (finish_reason=$finishReason)';
  }

  @override
  String ocrResultPageHeading(String index) {
    return 'Imagen $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return 'Imagen $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => '(resultado parcial)';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return 'Algunas imágenes no fueron reconocidas completamente: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return 'Imagen $index: resultado incompleto';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return 'Imagen $index: error de reconocimiento';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => ';';

  @override
  String get bgTaskInterruptedOnRestart =>
      'Interrumpido cuando se reinició la aplicación.';

  @override
  String get bgTaskOcrErrorDetailsHidden =>
      'Los detalles del error de OCR estaban ocultos';

  @override
  String get bgTaskErrorDetailsHidden =>
      'Los detalles del error estaban ocultos';

  @override
  String get notificationBannerTaskCompletedHeading => 'Tarea completada';

  @override
  String get notificationBannerTaskFailedHeading => 'Tarea fallida';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return 'Tarea completada: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return 'Tarea fallida: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title completado';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title falló: $error';
  }

  @override
  String get notificationUnknownError => 'Error desconocido';

  @override
  String get desktopTrayTooltip =>
      'Stroom se está ejecutando en segundo plano.';

  @override
  String get desktopTrayOpen => 'Baño abierto';

  @override
  String get desktopTrayShowMainWindow => 'Mostrar ventana principal';

  @override
  String get desktopTrayQuitStroom => 'Salir de Stroom';

  @override
  String get providerPresetExaDescription =>
      'Busque en la web, extraiga el contenido de la página y respalde la investigación en profundidad a través de Exa MCP, con búsqueda semántica y de palabras clave.';

  @override
  String get providerPresetExaApiKeyHint =>
      'Obtenga una clave API del sitio web de Exa.';

  @override
  String get providerPresetTavilyDescription =>
      'Un motor de búsqueda nativo de IA para búsquedas web en tiempo real optimizado para modelos de lenguaje grandes.';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Obtenga una clave API de Tavily. Admite ?tavilyApiKey= o una autorización: encabezado portador.';

  @override
  String get providerPresetJinaDescription =>
      'Un servicio de IA multimodal para extraer contenido web, generar incrustaciones y recuperar resultados de búsqueda.';

  @override
  String get providerPresetJinaApiKeyHint =>
      'Obtenga una clave API de Jina AI (token de portador) desde su sitio web.';

  @override
  String get providerPresetFirecrawlDescription =>
      'Un servicio de extracción y rastreo web que convierte páginas en Markdown limpio o datos estructurados.';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Obtenga una clave API de Firecrawl o pruébela sin clave con los límites del nivel gratuito.';

  @override
  String get providerPresetZhipuDescription =>
      'Servicio MCP de lector web de Zhipu AI para buscar y comprender páginas web.';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Obtenga una clave API (token de portador) de la plataforma abierta Zhipu AI.';

  @override
  String get providerPresetBraveSearchDescription =>
      'Un motor de búsqueda independiente centrado en la privacidad con resultados web de alta calidad.';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Obtenga una clave API del sitio web de Brave Search.';

  @override
  String get providerPresetBochaDescription =>
      'La búsqueda web de Bocha AI proporciona resultados de búsqueda inteligentes para páginas en idioma chino.';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Obtenga una clave API (token de portador) de la plataforma abierta Bocha AI.';

  @override
  String get providerPresetQueritDescription =>
      'La búsqueda de Querit AI ofrece búsqueda inteligente y descubrimiento de contenido.';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Obtenga una clave API (token de portador) del sitio web de Querit.';

  @override
  String get providerPresetSearxngDescription =>
      'Un metabuscador autohospedado que agrega fuentes de búsqueda centrándose en la privacidad.';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'Configure la URL de su instancia de SearXNG (por ejemplo, http://su-instancia:8080); una clave API es opcional.';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'La síntesis TTS falló: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return 'Error original: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      'Se agotó el tiempo de conexión de red. Verifique su red o dirección API.';

  @override
  String get ttsErrorServerResponseTimeout =>
      'Se agotó el tiempo de respuesta del servidor. Vuelve a intentarlo más tarde.';

  @override
  String ttsErrorConnectionFailed(String details) {
    return 'No se puede conectar al servidor ($details)';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return 'No se puede conectar con el servidor. Causas comunes en la aplicación web: restricciones de CORS o una dirección API incorrecta. $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'La API devolvió un error (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return 'Se agotó el tiempo de conexión. Comprueba tu red$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return 'Recibir tiempo de espera agotado; el servidor responde lentamente$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'La clave API no es válida o se ha denegado el permiso (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return 'Demasiadas solicitudes; Inténtelo de nuevo más tarde (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'Punto final API no encontrado (HTTP $status): $body\nCompruebe que la URL base de la API sea correcta$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return 'Error interno del servidor (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return 'El servidor devolvió un error (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return 'Solicitud cancelada$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return 'No se puede conectar con el servidor. Causas comunes en la aplicación web: restricciones de CORS o una dirección API incorrecta. Compruebe que la dirección API del proveedor sea correcta y que el servidor permita solicitudes de origen cruzado.$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return 'Error de red: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => 'Error de red desconocido';

  @override
  String get ttsErrorNoResponseBody => 'Sin cuerpo de respuesta';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return 'Error en la síntesis de streaming: $details';
  }

  @override
  String get mermaidEditorTitle => 'Editor de gráficos de sirena';

  @override
  String get mermaidEditorModeEdit => 'Editar';

  @override
  String get mermaidEditorModeSplit => 'Editar + Vista previa';

  @override
  String get mermaidEditorModePreview => 'Avance';

  @override
  String get mermaidEditorSwitchViewMode => 'Cambiar modo de vista';

  @override
  String get mermaidEditorSaveToTextStorage =>
      'Guardar en almacenamiento de texto';

  @override
  String get mermaidEditorEmptyChart =>
      'El contenido del gráfico está vacío y no se puede guardar.';

  @override
  String get mermaidEditorSaveChartTitle => 'Guardar gráfico';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      'Elija o cree una carpeta para guardar el archivo del gráfico .mmd';

  @override
  String get mermaidEditorFileNameHint =>
      'Ingrese un nombre de archivo (.mmd agregado automáticamente)';

  @override
  String get mermaidEditorEmptyFileName =>
      'El nombre del archivo no puede estar vacío';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return 'Guardado en almacenamiento de texto: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor =>
      'Intercambiar paneles de vista previa y editor';

  @override
  String get mermaidEditorCodeLabel => 'código sirena';

  @override
  String get mermaidEditorCodeHint => 'Introduce el código de sirena...';

  @override
  String get mermaidEditorSplitCodeLabel => 'Código';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'La conexión SSE falló (HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'La conexión SSE falló (HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable =>
      'Error en la conexión SSE: no se puede conectar al servidor';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'La solicitud HTTP falló (HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => 'Solicitud fallida';

  @override
  String get sseNetworkRequestFailed => 'Error en la solicitud de red';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return 'Error en la solicitud de red (HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return 'Error en la solicitud de red (HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable =>
      'Error en la solicitud de red: no se puede conectar al servidor';

  @override
  String get sseRequestCancelled => 'Solicitud cancelada';

  @override
  String get startupSafetyTitle => 'Protección de seguridad de datos';

  @override
  String get startupSafetyExportButton => 'Exportar datos';

  @override
  String get startupSafetyExitButton => 'Salir de la aplicación';

  @override
  String get startupSafetyUpdateButton => 'Actualizar aplicación';

  @override
  String get startupSafetyCheckingUpdates => 'Buscando actualizaciones...';

  @override
  String get startupSafetyUpToDate => 'Estás al día';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return 'Estos datos fueron creados por una versión más reciente de la aplicación ($version).\n\nEsta versión de la aplicación no puede leer los datos de forma segura. Instale la última versión para continuar. Tus datos no han sido modificados.';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      'No se pudo confirmar el estado de seguridad de los datos (el marcador de estado no se pudo leer o no era válido).\n\nPara evitar sobrescribir un posible estado congelado, se ha bloqueado el inicio sin reparar datos ni migrar formatos. Primero exporte su archivo de datos, luego salga de la aplicación, repare el marcador de estado y vuelva a intentarlo.';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return 'Error en la migración del formato de datos ($part).\n\nPara proteger sus datos, no se realizaron cambios. Vuelva a la versión anterior de la aplicación o espere una versión reparada antes de actualizar.';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return 'Error en la migración del formato de datos ($part).\n\nSus datos fueron restaurados a su estado previo a la migración. Para protegerla, regrese a la versión anterior de la aplicación o espere una versión reparada antes de actualizar.';
  }

  @override
  String get startupSafetyDataCorrupted =>
      'Los datos están dañados y no se pueden reparar automáticamente.\n\nLa aplicación se ha congelado para evitar daños mayores. Exporte su archivo de datos, luego impórtelo manualmente o reinstálelo.';

  @override
  String get startupSafetyPreferencesUnavailable =>
      'La aplicación no pudo leer las preferencias requeridas para las comprobaciones de inicio, por lo que el inicio se bloqueó para proteger sus datos.\n\nVerifique el espacio de almacenamiento o los permisos, luego vuelva a abrir la aplicación.';

  @override
  String get startupSafetyValidationUnavailable =>
      'La aplicación no pudo completar la verificación de seguridad de los datos de inicio, por lo que se bloqueó el inicio para proteger sus datos.\n\nVerifique la configuración del navegador y luego vuelva a abrir la aplicación.';

  @override
  String startupSafetyCheckFailed(String detail) {
    return 'Error en la comprobación de inicio: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      'El estado de seguridad de los datos no se pudo confirmar después de las comprobaciones de inicio (el marcador de estado no se pudo leer o no era válido).\n\nEl inicio se detuvo para evitar realizar más cambios en los datos. Exporte su archivo de datos, salga de la aplicación, repare el marcador de estado y vuelva a intentarlo.';

  @override
  String get catCatchConnectionTimeout =>
      'Se agotó el tiempo de conexión. Verifique el estado de su red o servidor.';

  @override
  String get catCatchSendTimeout =>
      'Se agotó el tiempo de espera de la solicitud durante el envío.';

  @override
  String get catCatchReceiveTimeout =>
      'Se agotó el tiempo de respuesta porque el servidor está tardando demasiado.';

  @override
  String get catCatchCannotConnect => 'No se pudo conectar al servidor.';

  @override
  String get catCatchConnectionError =>
      'No se pudo conectar al servidor. Compruebe que la URL sea correcta.';

  @override
  String get catCatchBadCertificate =>
      'No se pudo verificar el certificado del servidor.';

  @override
  String catCatchBadResponse(int statusCode) {
    return 'El servidor devolvió un error (HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => 'La solicitud fue cancelada.';

  @override
  String catCatchNetworkError(String message) {
    return 'Error de red: $message';
  }

  @override
  String get catCatchUnknownError => 'Error desconocido';

  @override
  String catCatchOriginalError(String message) {
    return 'Error original: $message';
  }

  @override
  String get catCatchWebDownloadHint =>
      'Los navegadores web no pueden descargar archivos multimedia directamente.';

  @override
  String get catCatchWebInstallExtension =>
      'Instale la extensión del navegador CatCatch y vuelva a intentarlo.';

  @override
  String get catCatchWebAuthorAttribution =>
      'Autor: 笨笨猫 (xifangczy). Gratis y de código abierto.';

  @override
  String get catCatchWebOfficialWarning =>
      'Asegúrate de que sea la versión del autor; Evite las versiones pagas o de imitación.';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      'Esta función requiere una cuenta iniciada. Inicie sesión usando el navegador en la esquina superior derecha.';

  @override
  String get catCatchNoUsableMedia =>
      'No se encontró ningún recurso multimedia utilizable. Verifique la URL y asegúrese de que se pueda acceder al sitio web.';

  @override
  String get catCatchRedownloadFileMissing =>
      'La descarga falló porque falta el archivo descargado.';

  @override
  String get catCatchRedownloadPathEmpty =>
      'La descarga falló porque la ruta del archivo descargado está vacía.';

  @override
  String get catCatchWebBrowserRequired =>
      'Esta página no puede exponer sus recursos sin un entorno de navegador. Intente utilizar la función en un dispositivo móvil o de escritorio, o pegue una URL directa de un archivo de video o audio.';

  @override
  String get catCatchPlaylistNoSegments =>
      'La lista de reproducción no tiene segmentos descargables.';

  @override
  String get catCatchDownloadedSourceMissing =>
      'Falta el archivo fuente descargado. Por favor descárguelo nuevamente.';

  @override
  String get appLogPageTitle => 'Registros de aplicaciones';

  @override
  String get appLogRefresh => 'Refrescar';

  @override
  String get appLogCleanupOldLogs => 'Limpiar registros viejos';

  @override
  String get appLogCleanupDone => 'Se limpiaron los troncos viejos.';

  @override
  String appLogRetentionNotice(int days) {
    return 'Retención de registros: solo se conservan los días $days más recientes. Los registros con más de $days días se limpian automáticamente.';
  }

  @override
  String get appLogWebUnsupported =>
      'Los registros locales no son compatibles con la web';

  @override
  String get appLogNoFiles => 'Aún no hay archivos de registro';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Actualizando automáticamente (intentos $count)...',
      one: 'Actualizando automáticamente (intento $count)...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated =>
      'Los registros se generan mientras la aplicación se está ejecutando.';

  @override
  String get appLogExport => 'Exportar';

  @override
  String get appLogDelete => 'Borrar';

  @override
  String get appLogConfirmDeleteTitle => 'Confirmar eliminación';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return '¿Eliminar el archivo de registro \"$fileName\"?';
  }

  @override
  String get appLogCancel => 'Cancelar';

  @override
  String appLogLoadFilesError(Object error) {
    return 'No se pudo cargar la lista de archivos de registro: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return 'El archivo de registro \"$fileName\" existe pero no se pudo leer; puede estar corrupto';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return 'No se encontró el archivo de registro \"$fileName\"; puede que lo hayan limpiado';
  }

  @override
  String appLogReadFileError(Object error) {
    return 'No se pudo leer el archivo de registro: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return 'Eliminado: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return 'Error al eliminar: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return 'No se encontró el archivo de registro \"$fileName\"';
  }

  @override
  String appLogPathCopied(String filePath) {
    return 'Ruta copiada: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return 'Error al exportar: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '$count línea',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => 'Copiar todo';

  @override
  String get appLogStructuredView => 'Vista estructurada';

  @override
  String get appLogRawView => 'Vista cruda';

  @override
  String appLogCopyError(Object error) {
    return 'Copia fallida: $error';
  }

  @override
  String get appLogCopyDone => 'Copié todo el contenido del registro.';

  @override
  String get iosContinuedTaskTitle => 'Tarea en segundo plano';

  @override
  String get mermaidCatalogTypeFlowchart => 'Diagrama de flujo';

  @override
  String get mermaidCatalogDescriptionFlowchart =>
      'Diagrama de flujo: muestra pasos, ramas y bucles';

  @override
  String get mermaidCatalogTypeSequenceDiagram => 'Diagrama de secuencia';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      'Diagrama de secuencia: muestra las interacciones entre los participantes.';

  @override
  String get mermaidCatalogTypeClassDiagram => 'diagrama de clases';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      'Diagrama de clases: muestra las relaciones entre los atributos y métodos de la clase.';

  @override
  String get mermaidCatalogTypeStateDiagram => 'diagrama de estado';

  @override
  String get mermaidCatalogDescriptionStateDiagram =>
      'Diagrama de estado: muestra transiciones de estado';

  @override
  String get mermaidCatalogTypeErDiagram => 'diagrama ER';

  @override
  String get mermaidCatalogDescriptionErDiagram =>
      'Diagrama ER: muestra las relaciones entre entidades';

  @override
  String get mermaidCatalogTypeGantt => 'diagrama de Gantt';

  @override
  String get mermaidCatalogDescriptionGantt =>
      'Diagrama de Gantt: muestra un cronograma del proyecto';

  @override
  String get mermaidCatalogTypePie => 'gráfico circular';

  @override
  String get mermaidCatalogDescriptionPie =>
      'Gráfico circular: muestra datos proporcionales';

  @override
  String get mermaidCatalogTypeJourney => 'Viaje del usuario';

  @override
  String get mermaidCatalogDescriptionJourney =>
      'Viaje del usuario: muestra el flujo de la experiencia del usuario';

  @override
  String get mermaidCatalogTypeGitGraph => 'gráfico de git';

  @override
  String get mermaidCatalogDescriptionGitGraph =>
      'Gráfico de Git: muestra ramas y confirmaciones';

  @override
  String get mermaidCatalogTypeMindmap => 'mapa mental';

  @override
  String get mermaidCatalogDescriptionMindmap =>
      'Mapa mental: muestra una jerarquía';

  @override
  String get mermaidCatalogTypeTimeline => 'Línea de tiempo';

  @override
  String get mermaidCatalogDescriptionTimeline =>
      'Línea de tiempo: muestra eventos en orden cronológico';

  @override
  String get mermaidCatalogTypeBlock => 'diagrama de bloques';

  @override
  String get mermaidCatalogDescriptionBlock =>
      'Diagrama de bloques: muestra el diseño y las relaciones de los bloques';

  @override
  String get mermaidCatalogTypeRequirement => 'Diagrama de requisitos';

  @override
  String get mermaidCatalogDescriptionRequirement =>
      'Diagrama de requisitos: muestra los requisitos y las relaciones de implementación.';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[Inicio]\n  B[Procesar paso]\n  C<MERMAID_OPEN_BRACE>Condición<MERMAID_CLOSE_BRACE>\n  D[Fin]\n\n  A --> B\n  B --> C\n  C -->|Sí| D\n  C -->|No| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"Usuario\" as user\n  participant \"Sistema\" as system\n  participant \"Base de datos\" as database\n\n  user->>system: Enviar solicitud\n  system->>database: Consultar datos\n  database-->>system: Devolver resultado\n  system-->>user: Mostrar resultado';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String nombre\n    +int edad\n    +getName() String\n    +setName(String nombre) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String studentId\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String teacherId\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"Pendiente\" as pending\n  state \"En proceso\" as processing\n  state \"Completado\" as completed\n  state \"Error\" as failed\n  [*] --> pending\n  pending --> processing\n  processing --> completed\n  processing --> failed\n  failed --> pending\n  completed --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CLIENTE ||--o<MERMAID_OPEN_BRACE> PEDIDO : realiza\n  PEDIDO ||--|<MERMAID_OPEN_BRACE> ARTICULO_PEDIDO : contiene\n  PRODUCTO ||--o<MERMAID_OPEN_BRACE> ARTICULO_PEDIDO : incluye\n  CLIENTE <MERMAID_OPEN_BRACE>\n    int id PK\n    string nombre\n    string correo\n  <MERMAID_CLOSE_BRACE>\n  PEDIDO <MERMAID_OPEN_BRACE>\n    int id PK\n    int id_cliente FK\n    date fecha_pedido\n  <MERMAID_CLOSE_BRACE>\n  PRODUCTO <MERMAID_OPEN_BRACE>\n    int id PK\n    string nombre\n    float precio\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title Cronograma del proyecto\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section Requisitos\n  Análisis de requisitos :a1, 2024-01-01, 14d\n  Diseño del prototipo   :a2, after a1, 10d\n\n  section Desarrollo\n  Desarrollo frontend   :b1, after a2, 20d\n  Desarrollo backend    :b2, after a2, 20d\n  Integración de API    :b3, after b1, 7d\n\n  section Pruebas\n  Pruebas funcionales   :c1, after b3, 10d\n  Despliegue            :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title Distribución de datos\n  \"Categoría A\" : 40\n  \"Categoría B\" : 25\n  \"Categoría C\" : 20\n  \"Categoría D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title Registro de usuario\n  section Registro\n    Abrir página de registro: 5: Usuario\n    Introducir datos: 3: Usuario\n    Enviar solicitud: 4: Usuario\n  section Verificación\n    Recibir código: 3: Sistema\n    Introducir código: 4: Usuario\n    Verificación correcta: 5: Sistema, Usuario';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"Commit inicial\"\n  commit id: \"Añadir función A\"\n  branch develop\n  checkout develop\n  commit id: \"Desarrollar función\"\n  commit id: \"Corregir error\"\n  checkout main\n  merge develop\n  commit id: \"Publicar v1.0\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((Gestión de proyectos))\n    Requisitos\n      Funcionales\n      No funcionales\n    Desarrollo\n      Frontend\n      Backend\n    Pruebas\n      Pruebas unitarias\n      Pruebas de integración\n    Despliegue\n      Entorno de pruebas\n      Entorno de producción';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title Hitos del proyecto\n  2024-Q1 : Análisis de requisitos : Plan confirmado\n  2024-Q2 : Desarrollo : Funciones implementadas\n  2024-Q3 : Pruebas : Corrección de errores : Optimización del rendimiento\n  2024-Q4 : Despliegue : Operación y mantenimiento';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"Requisitos\"] B[\"Desarrollo\"] C[\"Pruebas\"]\n  D[\"Despliegue\"] E[\"Operaciones\"] F[\"Supervisión\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement InicioSesion <MERMAID_OPEN_BRACE>\n    id: 1\n    text: El usuario puede iniciar sesión con su cuenta y contraseña\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element PaginaInicio <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element ServicioAutenticacion <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  PaginaInicio - satisfies -> InicioSesion\n  ServicioAutenticacion - verifies -> InicioSesion';

  @override
  String get mermaidCatalogDefaultFileName => 'mi tabla';

  @override
  String get mermaidCatalogActionAddNode => 'Agregar nodo';

  @override
  String get mermaidCatalogActionAddDecision => 'Agregar decisión';

  @override
  String get mermaidCatalogActionAddEdge => 'Agregar borde';

  @override
  String get mermaidCatalogActionAddSubgraph => 'Agregar subgrafo';

  @override
  String get mermaidCatalogActionAddParticipant => 'Agregar participante';

  @override
  String get mermaidCatalogActionAddRequest => 'Agregar solicitud';

  @override
  String get mermaidCatalogActionAddResponse => 'Agregar respuesta';

  @override
  String get mermaidCatalogActionAddNote => 'Agregar nota';

  @override
  String get mermaidCatalogActionAddClass => 'Agregar clase';

  @override
  String get mermaidCatalogActionAddInheritance => 'Agregar herencia';

  @override
  String get mermaidCatalogActionAddRelationship => 'Agregar relación';

  @override
  String get mermaidCatalogActionAddAggregation => 'Agregar agregación';

  @override
  String get mermaidCatalogActionAddState => 'Agregar estado';

  @override
  String get mermaidCatalogActionAddTransition => 'Agregar transición';

  @override
  String get mermaidCatalogActionAddStart => 'Agregar inicio';

  @override
  String get mermaidCatalogActionAddEnd => 'Añadir final';

  @override
  String get mermaidCatalogActionAddEntity => 'Agregar entidad';

  @override
  String get mermaidCatalogActionAddOneToMany => 'Agregar uno a muchos';

  @override
  String get mermaidCatalogActionAddManyToMany => 'Agregar muchos a muchos';

  @override
  String get mermaidCatalogActionAddOneToOne => 'Agregar uno a uno';

  @override
  String get mermaidCatalogActionAddPhase => 'Agregar fase';

  @override
  String get mermaidCatalogActionAddTask => 'Agregar tarea';

  @override
  String get mermaidCatalogActionAddDependentTask =>
      'Agregar tarea dependiente';

  @override
  String get mermaidCatalogActionAddMilestone => 'Agregar hito';

  @override
  String get mermaidCatalogActionAddCategory => 'Añadir categoría';

  @override
  String get mermaidCatalogActionAddTitle => 'Agregar título';

  @override
  String get mermaidCatalogActionAddSystemTask => 'Agregar tarea del sistema';

  @override
  String get mermaidCatalogActionAddMultiPersonTask =>
      'Agregar tarea para varias personas';

  @override
  String get mermaidCatalogActionAddCommit => 'Agregar compromiso';

  @override
  String get mermaidCatalogActionCreateBranch => 'Crear sucursal';

  @override
  String get mermaidCatalogActionSwitchBranch => 'Cambiar rama';

  @override
  String get mermaidCatalogActionMergeBranch => 'Fusionar rama';

  @override
  String get mermaidCatalogActionAddBranch => 'Agregar sucursal';

  @override
  String get mermaidCatalogActionAddChildBranch => 'Agregar rama secundaria';

  @override
  String get mermaidCatalogActionAddTopic => 'Agregar tema';

  @override
  String get mermaidCatalogActionAddPeriod => 'Agregar periodo';

  @override
  String get mermaidCatalogActionAddBlock => 'Agregar bloque';

  @override
  String get mermaidCatalogActionAddColumns => 'Agregar columnas';

  @override
  String get mermaidCatalogActionAddConnection => 'Agregar conexión';

  @override
  String get mermaidCatalogActionAddChildBlock => 'Agregar bloque infantil';

  @override
  String get mermaidCatalogActionAddRequirement => 'Agregar requisito';

  @override
  String get mermaidCatalogActionAddElement => 'Agregar elemento';

  @override
  String get mermaidCatalogActionAddVerification => 'Agregar verificación';

  @override
  String get mermaidCatalogGanttDependencyBaseTask =>
      'Tarea base de dependencia';

  @override
  String get mermaidCatalogGanttDependentTaskName => 'tarea de seguimiento';

  @override
  String get startupMigrationTitle =>
      'Actualización del formato de datos completada';

  @override
  String get startupMigrationBody =>
      'Sus datos han sido migrados al nuevo formato. Reinicie la aplicación para usar la versión actualizada.';

  @override
  String get startupMigrationExit => 'Salir de la aplicación';

  @override
  String get startupMigrationRestart => 'Reiniciar ahora';

  @override
  String get startupRecoveryTitle => 'Error de inicio de la aplicación';

  @override
  String get startupRecoveryFallbackMessage =>
      'Se encontró un problema de formato de datos durante el inicio y se reparó automáticamente. Por favor inténtalo de nuevo.';

  @override
  String get startupRecoveryRetry => 'Rever';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return 'ASR $category en $stage$chunk: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return ', fragmento $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return 'Solicitud fallida: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return 'Error en la transcripción fragmentada (fragmentos $count, ninguno exitoso)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return 'La transcripción fragmentada está incompleta (los fragmentos $succeeded/$count se realizaron correctamente)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return 'Tuvo éxito: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return 'Error: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return 'Resultado incierto: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return 'Fragmento $index ($start–${end}s) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return 'Error al guardar el estado del fragmento: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      'El resultado de la solicitud es incierto. Se detuvieron los reintentos para evitar envíos duplicados. Seleccione el audio nuevamente para crear una nueva tarea.';

  @override
  String asrRetryAudioLost(Object audioName) {
    return 'El archivo de audio original se perdió. Seleccione el audio nuevamente para volver a intentarlo: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return 'El archivo de audio original está dañado. Seleccione el audio nuevamente para volver a intentarlo: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return ', trozo $index';
  }

  @override
  String get asrChunkDetailsSeparator => ';';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'Error en el reconocimiento de ASR: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => 'autenticación';

  @override
  String get asrFailureCategoryRateLimit => 'límite de tasa';

  @override
  String get asrFailureCategorySizeLimit => 'límite de tamaño';

  @override
  String get asrFailureCategoryNetwork => 'red';

  @override
  String get asrFailureCategoryResponseParsing => 'análisis de respuesta';

  @override
  String get asrFailureCategoryLocalProcessing => 'procesamiento local';

  @override
  String get asrFailureCategoryProvider => 'proveedor';

  @override
  String get asrFailureCategoryUnknown => 'desconocido';

  @override
  String get asrFailureStagePreprocessing => 'preprocesamiento';

  @override
  String get asrFailureStageEncoding => 'codificación';

  @override
  String get asrFailureStageValidation => 'validación';

  @override
  String get asrFailureStageRequest => 'pedido';

  @override
  String get asrFailureStageUploading => 'subiendo';

  @override
  String get asrFailureStageWaiting => 'espera';

  @override
  String get asrFailureStageReceiving => 'recepción';

  @override
  String get asrFailureStageResponse => 'respuesta';

  @override
  String get asrFailureStageParsing => 'analizando';

  @override
  String get asrFailureStageStorage => 'almacenamiento';

  @override
  String get chatMissingProvider => 'Primero configure un proveedor de chat';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Error de API antrópico: $detail';
  }

  @override
  String get anthropicStreamUnknownError => 'Error desconocido';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'La solicitud de API falló (HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing =>
      'La clave API no está configurada; la carga de archivos no está disponible';

  @override
  String get fileUploadApiUrlMissing =>
      'La URL de API no está configurada; la carga de archivos no está disponible';

  @override
  String get fileUploadContentEmpty => 'El contenido del archivo está vacío.';

  @override
  String get fileUploadFilenameEmpty => 'El nombre del archivo está vacío.';

  @override
  String get fileUploadMimeTypeEmpty => 'El tipo MIME está vacío.';

  @override
  String get fileUploadPurposeEmpty => 'El propósito de carga está vacío';

  @override
  String get fileUploadCanceled => 'La carga del archivo fue cancelada.';

  @override
  String get fileUploadCreateMissingId =>
      'Error al crear la carga: falta la identificación de carga en la respuesta';

  @override
  String get fileUploadPartMissingId =>
      'Error al cargar la pieza: falta la identificación de la pieza en la respuesta';

  @override
  String get fileUploadCompleteMissingFile =>
      'Error al completar la carga: falta el objeto de archivo en la respuesta';

  @override
  String get fileUploadMissingFileId =>
      'Error al cargar el archivo: falta la identificación del archivo en la respuesta';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return 'Error en la solicitud de carga de archivos (HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return 'Error en la solicitud de carga de archivos: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'La clave API no está configurada';

  @override
  String chatStreamError(Object detail) {
    return 'Error de flujo de API: $detail';
  }

  @override
  String get chatChoicesMissing => 'La respuesta API no tiene opciones';

  @override
  String get chatContentBlocksMissing =>
      'La respuesta API no tiene bloques de contenido';

  @override
  String get chatResponseContentEmpty =>
      'El contenido de la respuesta API está vacío';

  @override
  String chatRequestFailed(Object detail) {
    return 'Solicitud fallida: $detail';
  }

  @override
  String get startupTagline => 'Tu asistente de aprendizaje';

  @override
  String get startupProgressDataSafety =>
      'Comprobando la seguridad de los datos...';

  @override
  String get startupProgressFormatVersion =>
      'Comprobando la versión del formato de datos...';

  @override
  String get startupProgressDataFormat => 'Validando formatos de datos...';

  @override
  String get startupProgressDataIntegrity =>
      'Comprobando la integridad de los datos...';

  @override
  String get startupProgressResults =>
      'Procesando resultados de verificación...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return 'Inicio completo (nota: $warning)';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      'Verificaciones de datos completadas. Preparándose para iniciar la aplicación.';

  @override
  String get startupProgressReady => 'Preparándose para iniciar la aplicación.';

  @override
  String startupWarningErrorCount(Object count) {
    return 'Problemas de datos encontrados con $count:';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return 'Advertencias $count:';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      'Las entradas del proveedor tienen un formato no válido: se esperaba una matriz JSON.';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return 'La entrada del proveedor $index es nula o tiene un tipo no válido.';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return 'A la entrada del proveedor $index le falta un ID o tiene un ID vacío.';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return 'A la entrada del proveedor $index le falta un tipo o tiene un tipo vacío.';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return 'A la entrada del proveedor $index le falta un nombre o tiene un nombre vacío.';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return 'El campo $field de la entrada de proveedor $index no es una lista válida.';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return 'La entrada del proveedor $index, $field contiene un elemento no válido que puede provocar un error de análisis.';
  }

  @override
  String get startupIssueConversationsInvalid =>
      'Las conversaciones tienen un formato no válido: se esperaba una matriz JSON.';

  @override
  String startupIssueConversationInvalid(Object index) {
    return 'La conversación $index es nula o tiene un tipo no válido.';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return 'A la conversación $index le falta un ID.';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return 'A la conversación $index le falta el campo de mensajes.';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return 'El campo de mensajes de conversación $index no es una lista válida.';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return 'La entrada de proveedor $index utiliza el tipo de proveedor desconocido \"$type\" y es posible que no funcione correctamente.';
  }

  @override
  String get startupErrorTitle => 'Error al iniciar la aplicación';

  @override
  String startupErrorDetails(Object error) {
    return 'Error: $error';
  }

  @override
  String get renderErrorTitle => 'Error de representación de interfaz';

  @override
  String get renderErrorDebugTitle =>
      'Error de representación de interfaz (modo de depuración)';

  @override
  String get renderErrorRestartMessage => 'Intente reiniciar la aplicación.';

  @override
  String get batchDlgFileName => 'Nombre del archivo';

  @override
  String get batchDlgFolderName => 'Nombre de la carpeta';

  @override
  String get batchDlgFileNameConflict =>
      'Otro archivo en esta carpeta tiene el mismo nombre.';

  @override
  String get batchDlgFolderNameConflict =>
      'Ya existe una carpeta con el mismo nombre en la ubicación de destino';

  @override
  String get batchDlgFolderNameSwapConflict =>
      'Los nombres de las carpetas no se pueden intercambiar en el mismo lote';

  @override
  String get batchDlgControlCharacterError =>
      'El nombre no puede contener caracteres de control';

  @override
  String get batchDlgNameWhitespaceError =>
      'El nombre no puede comenzar ni terminar con espacios en blanco; utilizar la regla de limpieza de espacios en blanco';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind no puede estar vacío';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind no puede terminar con espacios en blanco';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind no puede exceder los caracteres $count';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind no puede contener caracteres no válidos para Windows';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind no puede terminar con un punto';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind no puede utilizar un nombre reservado de Windows';
  }

  @override
  String get batchDlgIntermediateNameTooLong =>
      'Un nombre intermedio es demasiado largo; ajustar las reglas';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return 'Este artículo no tiene fecha $date; ajustar la plantilla';
  }

  @override
  String get batchDlgCreatedDate => 'creación';

  @override
  String get batchDlgModifiedDate => 'modificación';

  @override
  String get connectivityTestHttpSuccess =>
      'La solicitud de la herramienta HTTP se realizó correctamente';

  @override
  String get connectivityTestHttpFailure =>
      'Error en la solicitud de herramienta HTTP';

  @override
  String get connectivityTestInvalidMcpConfig =>
      'Configuración de MCP no válida';

  @override
  String get connectivityTestMissingTransport =>
      'Falta una configuración de tipo de transporte válida.';

  @override
  String get connectivityTestStdioUnsupported =>
      'stdio no es compatible con esta plataforma';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP requiere iniciar un proceso local. Pruébelo en la aplicación de escritorio Stroom.';

  @override
  String get connectivityTestInvalidContent => 'Contenido de prueba no válido';

  @override
  String get connectivityTestMethodMustBeString =>
      'El método debe ser una cadena.';

  @override
  String get connectivityTestUnsupportedMethod =>
      'Método de prueba no compatible';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      'Para evitar escribir datos comerciales remotos, las pruebas de conectividad de MCP solo permiten el método de lista/herramientas de solo lectura.';

  @override
  String get connectivityTestParamsMustBeObject =>
      'los parámetros deben ser un objeto JSON.';

  @override
  String get connectivityTestMcpConnectionFailed =>
      'No se pudo conectar al servicio MCP';

  @override
  String get connectivityTestCheckConnectionSettings =>
      'Verifique la dirección, la autenticación y la red, o vea el registro de la aplicación para obtener detalles de la conexión.';

  @override
  String get connectivityTestRemainingToolsOmitted =>
      '; herramientas restantes omitidas';

  @override
  String get connectivityTestMcpSuccess =>
      'La prueba de conectividad MCP fue exitosa';

  @override
  String connectivityTestToolNames(Object names) {
    return ': $names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return 'La conexión y la solicitud de lista/herramientas fueron exitosas; herramientas $count encontradas$names$suffix.';
  }

  @override
  String get connectivityTestTodoMutationBlocked =>
      'Los parámetros de prueba modificarían los datos de tareas pendientes.';

  @override
  String get connectivityTestTodoReadOnly =>
      'Para proteger la lista de tareas pendientes de la sesión actual, omita todas o configúrela como nula en las pruebas de conectividad.';

  @override
  String get connectivityTestUnknownBuiltin =>
      'Herramienta incorporada desconocida';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return 'No se encontró ningún ejecutor de prueba para la herramienta \"$toolName\".';
  }

  @override
  String get connectivityTestBuiltinSuccess =>
      'La prueba de la herramienta incorporada fue exitosa';

  @override
  String get connectivityTestBuiltinFailure =>
      'La prueba de la herramienta integrada falló';

  @override
  String get connectivityTestTopLevelObjectRequired =>
      'El contenido de la prueba debe ser un objeto JSON de nivel superior.';

  @override
  String get connectivityTestRequestTimeout =>
      'Se agotó el tiempo de espera de la solicitud. Consulta la respuesta del servicio y la red.';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'Se agotó el tiempo de espera de la solicitud de MCP: $method';
  }

  @override
  String get connectivityTestResultTruncated => '… (resultado truncado)';

  @override
  String get toolResultWebSearchEmptyQuery =>
      'Error: la consulta de búsqueda no puede estar vacía.';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return 'Error: Motor de búsqueda no compatible \"$source\". Valores admitidos: google, bing, baidu.';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return 'El motor preferido $preferred $reason; cambiado a $fallback.';
  }

  @override
  String get toolResultWebSearchNotFound =>
      'No se encontraron resultados de búsqueda relevantes.';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return 'No se encontraron resultados de búsqueda relevantes ($sources explícitamente no arrojó resultados).';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return 'Búsqueda incompleta: $sources explícitamente no arrojó resultados; otros motores no estaban disponibles o devolvieron páginas que no se pudieron analizar: $failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return 'Error: Todos los motores de búsqueda no están disponibles. $failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return 'Resultados de la búsqueda de $source:';
  }

  @override
  String get toolResultWebSearchLinkLabel => 'Enlace';

  @override
  String get toolResultWebSearchSummaryLabel => 'Resumen';

  @override
  String get toolResultWebSearchEmptyResults =>
      'No se encontraron resultados de búsqueda relevantes.';

  @override
  String get toolResultTodoInvalid =>
      'Error: el parámetro todos debe ser una matriz (omítalo o pase nulo para leer la lista de tareas pendientes).';

  @override
  String get toolResultTodoEmpty => 'Aún no hay tareas pendientes.';

  @override
  String toolResultTodoCount(Object count) {
    return 'Elementos pendientes activos: $count';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return 'Error: No se pudo volver a conectar al servidor MCP \"$server\".';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return 'Error: el servidor MCP \"$server\" no está disponible actualmente.';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return 'Error: el servidor MCP \"$server\" no pudo conectarse o no devolvió herramientas. Verifique la configuración del servidor.';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return 'La herramienta real \"$tool\" está publicada con el nombre de llamada \"$alias\" en este servidor.';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return 'La herramienta \"$tool\" la proporcionan varios servidores MCP; utilice el nombre de llamada coincidente: $routes.';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return 'Error: la herramienta real \"$tool\" tiene un conflicto de nombres. Utilice uno de los nombres de llamada enumerados anteriormente.';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return 'Error: el servidor MCP \"$server\" no tiene ninguna herramienta llamada \"$tool\".';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return 'Herramientas disponibles en este servidor: $tools. Utilice estos nombres en su lugar.';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return 'Error: la herramienta MCP \"$tool\" tiene actualmente un alias conflictivo. Utilice el nombre de llamada coincidente: $routes.';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return 'Error: la herramienta \"$tool\" está deshabilitada.';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return 'Error: herramienta desconocida \"$tool\"';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => 'no devolvió resultados';

  @override
  String get toolResultWebSearchFallbackUnavailable =>
      'no está disponible temporalmente';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '(servidor MCP $server)';
  }

  @override
  String get toolResultWebSearchUnparsedResults =>
      'devolvió una página que no se pudo analizar';

  @override
  String get toolResultSearchTitleLabel => 'Título';

  @override
  String get toolResultSearchContentLabel => 'Contenido';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return 'Error: La clave API $provider no está configurada. Configurarlo en ajustes.';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return 'Error: la URL de la instancia $provider no está configurada. Configurarlo en ajustes.';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return 'Error: Error en la solicitud $provider (HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return 'Error: Error en la solicitud $provider: $detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return 'Error: herramienta HTTP desconocida \"$provider\"';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return 'Error: el servidor MCP \"$server\" no está conectado.';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return 'Error: No hay respuesta de la herramienta MCP \"$tool\".';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return 'Error: $detail';
  }

  @override
  String get httpToolBraveDescription =>
      'Busque en la web con Brave Search API. Requiere una clave API.';

  @override
  String get httpToolBochaDescription =>
      'Busque en la web con la API de búsqueda Bocha AI. Requiere una clave API.';

  @override
  String get httpToolQueritDescription =>
      'Busque en la web con Querit Search. Requiere una clave API.';

  @override
  String get httpToolSearxngDescription =>
      'Un metabuscador autohospedado y centrado en la privacidad que agrega fuentes de búsqueda. Requiere una URL de instancia.';

  @override
  String get httpToolSearchQueryDescription => 'Términos de búsqueda.';

  @override
  String get httpToolSearchCountDescription =>
      'Número de resultados a devolver.';

  @override
  String get httpToolSearchCountMax20Description =>
      'Número de resultados a devolver (máximo 20).';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return 'Mazos $decks, notas $notes y tarjetas $cards importadas';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return 'No se pudo encontrar el archivo .apkg seleccionado: $path';
  }

  @override
  String get backupRestoreApkgInvalidArchive =>
      'El archivo .apkg seleccionado está dañado o no es un archivo válido.';

  @override
  String get backupRestoreApkgCollectionMissing =>
      'El archivo .apkg no contiene collection.anki2.';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return 'Abra las tarjetas didácticas de Anki antes de importar o exportar un mazo: $path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt =>
      'La base de datos de la colección de Anki está dañada.';

  @override
  String backupRestoreApkgLocalFileFailure(String path) {
    return 'No se pudo acceder al archivo Anki local: $path';
  }

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return 'La operación .apkg falló al acceder a esta ruta: $path';
  }

  @override
  String get backupRestoreApkgOperationFailed =>
      'La operación .apkg falló porque no se pudo leer el archivo o la base de datos.';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return 'La plataforma Anki no se pudo empaquetar desde esta base de datos: $path';
  }

  @override
  String get ankiSyncStatusProtocolFailed =>
      'La respuesta del servidor de sincronización no es válida o está incompleta. Verifique que el servidor admita Anki sync v10.';

  @override
  String get ankiSyncStatusLoginRequired =>
      'Inicie sesión en Anki Sync antes de continuar.';

  @override
  String get ankiSyncStatusInvalidServerUrl =>
      'Ingrese una dirección de servidor de sincronización HTTP o HTTPS válida.';

  @override
  String get ankiSyncStatusHttpsRequired =>
      'Los servidores de sincronización remotos autohospedados deben utilizar HTTPS.';

  @override
  String get ankiSyncStatusConnectionTimeout =>
      'Se agotó el tiempo de espera de la solicitud de sincronización. Verifique la dirección del servidor y la red, luego vuelva a intentarlo.';

  @override
  String get ankiSyncStatusTlsFailure =>
      'No se pudo verificar el certificado del servidor. Verifique el certificado o configure una CA personalizada.';

  @override
  String get ankiSyncStatusConnectionFailure =>
      'No se pudo conectar al servidor de sincronización. Verifique la dirección y la red.';

  @override
  String get ankiSyncStatusRequestFailure =>
      'La solicitud de sincronización falló. Verifique el servidor y la red, luego vuelva a intentarlo.';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return 'El servidor de sincronización devolvió HTTP $statusCode.';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return 'La respuesta de sincronización superó el límite de MB $limitMb.';
  }

  @override
  String get ankiSyncStatusLocalFileFailure =>
      'No se pudo leer ni limpiar un archivo de sincronización local. Verifique el acceso al disco y vuelva a intentarlo.';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      'La colección no se pudo abrir, actualizar ni pasar la validación de esquema/SQLite. Restaure una colección válida o descárguela nuevamente.';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return 'El servidor de sincronización rechazó la solicitud (HTTP $statusCode). Verifique las credenciales de inicio de sesión y los permisos del servidor.';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return 'No se pudo encontrar el punto final de sincronización (HTTP $statusCode). Verifique la dirección del servidor.';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      'El servidor de sincronización de medios devolvió una respuesta no válida. Comprueba que sea compatible con la sincronización de medios Anki y vuelve a intentarlo.';

  @override
  String get ankiSyncStatusMediaIndexCorrupt =>
      'El índice de sincronización de medios local está dañado. Restablezca los datos de sincronización de medios e inténtelo de nuevo.';

  @override
  String get ankiSyncStatusMediaIndexFailure =>
      'No se pudo leer ni actualizar el índice de sincronización de medios local.';

  @override
  String get ankiSyncStatusMediaChecksumMismatch =>
      'Un archivo multimedia descargado no superó la validación de la suma de comprobación. Vuelva a intentar la sincronización de medios.';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return 'El archivo multimedia “$filename” tiene cambios locales y de servidor contradictorios. Haga una copia de seguridad y resuelva el conflicto de nombres antes de volver a intentarlo.';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return 'El nombre del archivo multimedia “$filename” no se puede sincronizar. Cambie el nombre a un nombre de archivo Anki válido y vuelva a intentarlo.';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return 'Un archivo multimedia está vacío o supera el límite de MB $limitMb.';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return 'El archivo multimedia contiene entradas $count; el máximo es $limit incluido su manifiesto.';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed =>
      'Error en la verificación de sincronización de medios. Vuelva a intentar la sincronización.';

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      'Inicie sesión en AnkiWeb para sincronizar en la web. Abra la configuración de Anki con el ícono de la nube para iniciar sesión.';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      'Para explorar o administrar mazos en la web, inicie sesión en AnkiWeb usando el ícono de la nube.';

  @override
  String get ankiStatsUnsupportedPlatform =>
      'Las estadísticas de Anki no están disponibles en esta plataforma.';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      'El reloj del dispositivo difiere del del servidor de sincronización en más de 5 minutos. Corrige el reloj y vuelve a intentarlo.';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      'La verificación de estado de sincronización falló y los cambios locales se revirtieron. Descargue la colección de servidores completa y vuelva a intentarlo.';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      'Esta colección no se puede sincronizar de forma incremental. Elija una carga o descarga completa para continuar.';

  @override
  String get ankiSyncStatusIncrementalSyncFailed =>
      'No se pudo completar la sincronización incremental. Verifique el servidor y la conexión, luego inténtelo nuevamente.';

  @override
  String get emojiCategorySmileys => 'Emoticonos';

  @override
  String get emojiCategoryPeople => 'Gente';

  @override
  String get emojiCategoryAnimals => 'animales';

  @override
  String get emojiCategoryFood => 'Alimento';

  @override
  String get emojiCategoryActivities => 'Actividades';

  @override
  String get emojiCategoryTravel => 'Viajar';

  @override
  String get emojiCategoryObjects => 'Objetos';

  @override
  String get emojiCategorySymbols => 'Símbolos';

  @override
  String get emojiCategoryFlags => 'Banderas';

  @override
  String get languageNameSpanish => 'Español';

  @override
  String get languageNameJapanese => 'japonés';

  @override
  String fileManagerDeleteEmptyFolderWithSubfoldersConfirm(
    Object count,
    Object name,
  ) {
    return '¿Eliminar la carpeta vacía “$name”? También se eliminarán sus $count subcarpetas.';
  }
}

/// The translations for Spanish Castilian, as used in Spain (`es_ES`).
class AppLocalizationsEsEs extends AppLocalizationsEs {
  AppLocalizationsEsEs() : super('es_ES');

  @override
  String get galleryPermissionTitle =>
      'Se requiere acceso a la biblioteca de fotografías';

  @override
  String get galleryPermissionMessage =>
      'Permita que Stroom acceda a fotos y videos en la configuración del sistema.';

  @override
  String get galleryPermissionCancel => 'Cancelar';

  @override
  String get galleryPermissionOpenSettings => 'Abrir configuración';

  @override
  String get languageSettingsTitle => 'Idioma';

  @override
  String get followSystemLanguage => 'Seguir sistema';

  @override
  String get themeDisplaySettingsTitle => 'Tema y visualización';

  @override
  String get themeDisplayThemeSection => 'Tema';

  @override
  String get themeModeLight => 'Modo claro';

  @override
  String get themeModeDark => 'modo oscuro';

  @override
  String get themeModeSystem => 'Seguir sistema';

  @override
  String get languageNameEnglish => 'Inglés';

  @override
  String get languageNameChinese => 'Chino (simplificado)';

  @override
  String get languageSearchHint => 'Idiomas de búsqueda';

  @override
  String get languageNoMatches => 'No hay idiomas coincidentes';

  @override
  String get builtInPromptGeneralName => 'asistente general';

  @override
  String get builtInPromptGeneralDescription =>
      'Un asistente de IA multiuso para conversaciones cotidianas y respuestas a una amplia gama de preguntas.';

  @override
  String get builtInPromptGeneralPrompt =>
      'Eres un útil asistente de IA. Responder al usuario en el idioma que utiliza. Sea conciso, claro y organizado lógicamente. Si no está seguro de algo, dígalo honestamente.';

  @override
  String get builtInPromptCodeExpertName => 'Experto en código';

  @override
  String get builtInPromptCodeExpertDescription =>
      'Un programador experimentado con experiencia en muchos lenguajes de programación y pilas de tecnología.';

  @override
  String get builtInPromptCodeExpertPrompt =>
      'Usted es un ingeniero de software experimentado y experto en muchos lenguajes de programación y pilas de tecnología. Según la pregunta del usuario, proporcione ejemplos de código de alta calidad, explicaciones técnicas y recomendaciones de mejores prácticas. Priorice la legibilidad, el rendimiento y la seguridad. Al proporcionar el código, etiquete el idioma y utilice el formato adecuado. Para preguntas sobre diseño de sistemas, analice las compensaciones desde una perspectiva de arquitectura.';

  @override
  String get builtInPromptTranslationName => 'Asistente de traducción';

  @override
  String get builtInPromptTranslationDescription =>
      'Un traductor profesional para traducción multilingüe y asesoramiento en localización.';

  @override
  String get builtInPromptTranslationPrompt =>
      'Eres un traductor profesional. Tus responsabilidades son:\n1. Traducir con precisión el contenido que proporciona el usuario conservando su estilo y tono.\n2. Dar una expresión natural cuando el usuario pregunte cómo decir algo en un idioma en particular.\n3. Ofrecer asesoramiento sobre localización de contenidos culturalmente específicos.\n4. Cuando sean posibles varias traducciones, enumerelas y explique sus diferencias.\nIdentifique siempre primero los idiomas de origen y de destino; Pregúntele al usuario si alguno de los dos no está claro.';

  @override
  String get builtInPromptEnglishTeacherName => 'profesora de ingles';

  @override
  String get builtInPromptEnglishTeacherDescription =>
      'Un tutor de aprendizaje de inglés que ayuda a mejorar la escucha, el habla, la lectura y la escritura.';

  @override
  String get builtInPromptEnglishTeacherPrompt =>
      'Eres un profesor de inglés con experiencia. Satisfacer las necesidades del usuario con:\n1. Explicaciones gramaticales: explique las reglas con claridad e incluya ejemplos.\n2. Aprendizaje de vocabulario: explicar el uso, las colocaciones y las distinciones de las palabras.\n3. Escritura pulida: mejora el inglés para que suene natural.\n4. Práctica de conversación: simular situaciones de habla inglesa.\n5. Guía de pronunciación: utilice símbolos fonéticos y pronunciación aproximada.\nAjuste la dificultad al nivel de inglés del usuario y utilice el español para facilitar las explicaciones.';

  @override
  String get builtInPromptInterviewerName => 'Entrevistador';

  @override
  String get builtInPromptInterviewerDescription =>
      'Un entrevistador simulado para entrevistas técnicas y conductuales.';

  @override
  String get builtInPromptInterviewerPrompt =>
      'Eres un entrevistador profesional. Realice una entrevista de práctica para el rol objetivo del usuario:\n1. Primero, conozca la posición y la industria de destino.\n2. Haga preguntas técnicas, de comportamiento y de diseño de sistemas relevantes.\n3. Evaluar las respuestas del usuario y sugerir mejoras.\n4. Proporcione ejemplos de respuestas y razonamientos.\n5. Mantenga un ritmo realista: haga una o dos preguntas y luego espere al usuario.\nSea profesional y amigable, con el objetivo de ayudar al usuario a mejorar sus habilidades para la entrevista.';

  @override
  String get builtInPromptWritingName => 'Asistente de redacción';

  @override
  String get builtInPromptWritingDescription =>
      'Un asistente de redacción y edición para muchos géneros y escritura creativa.';

  @override
  String get builtInPromptWritingPrompt =>
      'Eres un consultor de redacción profesional. Según las necesidades del usuario, proporcione:\n1. Redacción: escribir en géneros como argumentativo, expositivo y narrativo.\n2. Edición: mejorar la gramática, la elección de palabras, la lógica, la estructura y la expresión.\n3. Delinear: ayudar a construir un marco e identificar puntos clave.\n4. Ideas creativas: ofrece inspiración y ángulos posibles.\n5. Formato: siga las convenciones del género de destino y los requisitos de envío.\nPrimero, comprenda el propósito, los lectores previstos y el estilo deseado, luego brinde consejos específicos.';

  @override
  String get builtInPromptCreativeThinkerName => 'Pensador creativo';

  @override
  String get builtInPromptCreativeThinkerDescription =>
      'Un socio de ideas creativas y lluvia de ideas que genera nuevas ideas.';

  @override
  String get builtInPromptCreativeThinkerPrompt =>
      'Eres un compañero de pensamiento creativo. Tus tareas son:\n1. Lluvia de ideas: ofrezca direcciones creativas variadas en torno a un tema.\n2. Desarrollar conceptos: profundizar y ampliar las ideas existentes.\n3. Conectar campos: combinar conceptos de diferentes áreas de nuevas formas.\n4. Pensar al revés: desafiar el pensamiento convencional y ofrecer perspectivas inusuales.\n5. Revisión de viabilidad: analizar los desafíos de implementación y el valor potencial.\nFomente el pensamiento divergente mientras enfoca la discusión en el momento adecuado. Ofrezca de tres a cinco instrucciones por respuesta.';

  @override
  String get builtInPromptDataAnalystName => 'Analista de datos';

  @override
  String get builtInPromptDataAnalystDescription =>
      'Un experto en análisis de datos que ayuda a comprender, modelar y visualizar datos.';

  @override
  String get builtInPromptDataAnalystPrompt =>
      'Eres un experto en análisis de datos. Según la pregunta del usuario, proporcione:\n1. Métodos de análisis: elegir métodos estadísticos y marcos analíticos adecuados.\n2. Código SQL/Python/R: proporcione ejemplos de procesamiento y análisis de datos.\n3. Consejos de visualización: recomiende tipos de gráficos y herramientas adecuados.\n4. Interpretación: explicar los hallazgos y su significado comercial.\n5. Limpieza de datos: maneje valores faltantes, valores atípicos y otros problemas de calidad.\nPrimero, aclare el objetivo del análisis y las características de los datos. Prefiere el ecosistema Python (pandas, numpy, matplotlib, seaborn).';

  @override
  String get builtInPromptRoleplayName => 'Juego de roles';

  @override
  String get builtInPromptRoleplayDescription =>
      'Una experiencia de juego de rol inmersiva con múltiples personajes.';

  @override
  String get builtInPromptRoleplayPrompt =>
      'Ya estás en modo de interpretación. Interpreta al personaje indicado por el usuario y responde de acuerdo con su personalidad, tono y conocimientos:\n1. Cuando el usuario diga «interpreta a [personaje]», cambia de inmediato a ese personaje.\n2. Mantén el papel durante toda la conversación.\n3. Adapta el estilo y los conocimientos del personaje a su descripción.\n4. El usuario puede decir «terminar el juego de rol» para detenerlo.\n5. Puedes añadir detalles ficticios razonables que encajen con el personaje.\nEspera a que el usuario indique qué personaje quiere que interpretes.';

  @override
  String get builtInPromptLifeAdvisorName => 'Asesor de vida';

  @override
  String get builtInPromptLifeAdvisorDescription =>
      'Un oyente cálido y atento que ofrece apoyo para la salud mental y consejos cotidianos.';

  @override
  String get builtInPromptLifeAdvisorPrompt =>
      'Eres un asesor de vida cálido y reflexivo. Tus responsabilidades son:\n1. Escuchar activamente y comprender las inquietudes y necesidades emocionales del usuario.\n2. Analizar los problemas de forma racional y ayudar al usuario a analizar sus aspectos.\n3. Ofrecer formas concretas y viables de mejorar la vida cotidiana.\n4. Brinde comprensión, aliento y apoyo positivo.\n5. Sugerir ayuda profesional cuando sea necesario.\nRecuerde: usted no es un consejero de salud mental autorizado. En caso de una crisis grave de salud mental, anime al usuario a buscar ayuda profesional. Sea empático sin excederse; apoyar al usuario sin tomar decisiones por él.';

  @override
  String get builtInSystemTitleName => 'Asistente de título';

  @override
  String get builtInSystemTitleDescription =>
      'Genera un título corto automáticamente a partir de la conversación.';

  @override
  String get builtInSystemTitlePrompt =>
      'Eres un generador de títulos. Muestra un título de conversación y nada más.\n\nReglas:\n- Utilice una línea y no más de 50 caracteres.\n- No explicar ni utilizar comillas.\n- Utilizar el mismo idioma que los mensajes del usuario.\n- No incluya nombres de herramientas como web_search o todowrite en el título.\n\nEjemplos:\n“Ayúdame a depurar un error de producción 500” → Depurar un error de producción 500\n“Refactorizar el servicio de usuario” → Refactorizar el servicio de usuario\n\"¿Por qué falla app.js?\" → Solución de problemas de app.js\n\nSi el mensaje del usuario es muy breve o simplemente un saludo (como “hola”, “jaja” o “¿estás ahí?”), crea un título que refleje su tono o intención, como un saludo, una charla informal o una confirmación rápida.';

  @override
  String get builtInSystemCompactionName =>
      'Asistente de compactación de contexto';

  @override
  String get builtInSystemCompactionDescription =>
      'Condensa una larga conversación en un resumen estructurado y anclado para liberar espacio de contexto.';

  @override
  String get builtInSystemCompactionPrompt =>
      'Eres un asistente de resúmenes de contexto anclado. Condense largas conversaciones en resúmenes estructurados.\n\nResuma solo el historial de conversaciones proporcionado. Los mensajes recientes pueden conservarse palabra por palabra, así que concéntrese en el contexto más antiguo que aún sea importante.\n\nSi el mensaje contiene un bloque <previous-summary>, trátelo como el resumen anclado actual: mantenga lo que aún es cierto, elimine el material obsoleto e integre nuevos hechos.\n\nSiga esta estructura exactamente. Mantenga el orden de las secciones e incluya todas las secciones, incluso si están vacías:\n<plantilla>\n## Objetivo\n- [El objetivo del usuario en una o dos frases]\n\n## Detalles importantes\n- [Limitaciones/preferencias, decisiones y razones, hechos/suposiciones importantes y contexto preciso necesario para continuar; escriba (ninguno) si está vacío]\n\n## Estado de trabajo\n### Completado\n- [Trabajo completado, hechos verificados o cambios realizados; escriba (ninguno) si está vacío]\n\n### Activo\n- [Trabajo actual, cambios parciales o investigación; escriba (ninguno) si está vacío]\n\n### Bloqueado\n- [Bloqueadores, comandos fallidos o desconocidos; escriba (ninguno) si está vacío]\n\n## Siguiente movimiento\n1. [La siguiente acción específica, o (ninguna)]\n2. [Acción de seguimiento conocida, o (ninguna)]\n\n## Archivos relevantes\n- [Ruta del archivo o directorio y por qué es importante; escriba (ninguno) si está vacío]\n</plantilla>\n\nReglas:\n- Incluir todas las secciones, incluso si están vacías.\n- Utilice viñetas concisas, no párrafos.\n- Conserve rutas exactas de archivos, símbolos, comandos, mensajes de error, URL e identificadores.\n- No menciones que estás resumiendo, compactando o fusionando contexto.\n- Utilizar el mismo lenguaje de la conversación.';

  @override
  String get builtInPromptMarketTitle => 'Asistente de Mercado';

  @override
  String get builtInPromptClose => 'Cerrar';

  @override
  String get builtInPromptImportHint =>
      'Las indicaciones importadas se convierten en asistentes habituales que puedes editar libremente.';

  @override
  String get builtInPromptView => 'Ver aviso';

  @override
  String get builtInPromptAdd => 'Agregar';

  @override
  String get builtInPromptDescriptionHeading => 'Descripción';

  @override
  String get builtInPromptSystemPromptHeading => 'Aviso del sistema';

  @override
  String get builtInPromptAddAssistant => 'Agregar asistente';

  @override
  String builtInPromptViewerTitle(Object name) {
    return 'Aviso · $name';
  }

  @override
  String get systemAssistantSettingsIntro =>
      'Configure un modelo separado y solicite la generación automática de títulos y la compactación del contexto. De forma predeterminada, se utilizan el modelo de chat actual y las indicaciones integradas.';

  @override
  String get systemAssistantTitleName => 'Asistente de generación de títulos';

  @override
  String get systemAssistantTitleDescription =>
      'Genera automáticamente títulos de conversaciones';

  @override
  String get systemAssistantCompactionName =>
      'Asistente de compactación de contexto';

  @override
  String get systemAssistantCompactionDescription =>
      'Condensa largas conversaciones en resúmenes anclados';

  @override
  String get systemAssistantFollowCurrentModel =>
      'Sigue el modelo de chat actual';

  @override
  String get systemAssistantChooseModel => 'Elige un modelo';

  @override
  String get systemAssistantResetPromptTitle =>
      'Restablecer el mensaje predeterminado';

  @override
  String systemAssistantResetPromptBody(Object taskTitle) {
    return '¿Restaurar el mensaje predeterminado incorporado para “$taskTitle”? Su mensaje personalizado actual será descartado.';
  }

  @override
  String get systemAssistantCancel => 'Cancelar';

  @override
  String get systemAssistantReset => 'Reiniciar';

  @override
  String get systemAssistantModelHeading => 'Modelo';

  @override
  String get systemAssistantPromptHeading => 'Instrucción';

  @override
  String get systemAssistantCustomPromptHint =>
      'Los cambios se utilizarán como un mensaje personalizado.';

  @override
  String get systemAssistantUsingCustomPrompt =>
      'Usando un mensaje personalizado';

  @override
  String get systemAssistantUsingDefaultPrompt =>
      'Usando el mensaje predeterminado';

  @override
  String get systemAssistantSave => 'Guardar';

  @override
  String get systemAssistantResetButton =>
      'Restablecer el mensaje predeterminado';

  @override
  String get taskFlowPageTitle => 'Flujos de tareas';

  @override
  String get taskFlowSampleTemplatesTooltip => 'Plantillas de ejemplo';

  @override
  String get taskFlowEmptyState => 'Aún no hay flujos. Toca + para crear uno.';

  @override
  String get taskFlowStartFromTemplate => 'Empezar desde una plantilla';

  @override
  String get taskFlowChooseTemplate => 'Elija una plantilla de ejemplo';

  @override
  String get taskFlowTemplateIntroduction =>
      'Elija un flujo cercano a lo que necesita; Puedes ajustarlo más tarde.';

  @override
  String taskFlowTemplateCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plantillas',
      one: '$count plantilla',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowTemplateDraftHint =>
      'Las plantillas se abren como borradores que necesitan configuración. Elija un modelo y asistente antes de guardar.';

  @override
  String get taskFlowTemplateRecordingName =>
      'Transcribir y resumir una grabación';

  @override
  String get taskFlowTemplateRecordingDescription =>
      'Elija una grabación → reconocimiento de voz → resumen del asistente';

  @override
  String get taskFlowTemplateRecordingRequirements =>
      'Configura un modelo ASR y elige un asistente para el resumen.';

  @override
  String get taskFlowTemplateImageTextName =>
      'Reconocer y organizar texto de imagen';

  @override
  String get taskFlowTemplateImageTextDescription =>
      'Elija una imagen → reconocimiento de texto → organización asistente';

  @override
  String get taskFlowTemplateImageTextRequirements =>
      'Configura un modelo OCR y elige un asistente para organizar el texto.';

  @override
  String get taskFlowTemplateReadImageName => 'Leer texto de una imagen';

  @override
  String get taskFlowTemplateReadImageDescription =>
      'Elija una imagen → reconocimiento de texto → reproducción de voz';

  @override
  String get taskFlowTemplateReadImageRequirements =>
      'Configure los modelos de síntesis de voz y OCR y luego elija una voz.';

  @override
  String get taskFlowActions => 'Acciones de flujo';

  @override
  String taskFlowBlockCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bloques',
      one: '$count bloque',
    );
    return '$_temp0';
  }

  @override
  String get taskFlowBlockOcr => 'LOC';

  @override
  String get taskFlowBlockAsr => 'Reconocimiento de voz';

  @override
  String get taskFlowBlockAudioSeparation => 'Separación de audio';

  @override
  String get taskFlowBlockCatCatch => 'Descarga de recursos web';

  @override
  String get taskFlowBlockTts => 'Síntesis del habla';

  @override
  String get taskFlowBlockChat => 'Asistente de chat';

  @override
  String get taskFlowBlockCustom => 'Bloque personalizado';

  @override
  String get taskFlowEdit => 'Editar';

  @override
  String get taskFlowCopy => 'Copiar';

  @override
  String get taskFlowCopied => 'Copiado';

  @override
  String get taskFlowDelete => 'Borrar';

  @override
  String get taskFlowConfirmDelete => 'Confirmar eliminación';

  @override
  String taskFlowConfirmDeleteBody(Object flowName) {
    return '¿Eliminar el flujo de tareas “$flowName”?';
  }

  @override
  String get taskFlowUseTemplate => 'Usar';

  @override
  String get taskFlowOcrInputMissing =>
      'No se pudo encontrar el archivo de imagen. Seleccione la imagen nuevamente.';

  @override
  String get taskFlowOcrInputReadFailed =>
      'No se pudo leer el archivo de imagen. Verifique el acceso al archivo e inténtelo nuevamente.';

  @override
  String get taskFlowOcrModelUnavailable =>
      'No se ha configurado ningún modelo de OCR utilizable. Elija un proveedor y modelo de OCR en la configuración de flujo.';

  @override
  String taskFlowOcrRequestSizeLimit(Object size) {
    return 'Presupuesto de tamaño de solicitud de OCR ($size MiB)';
  }

  @override
  String taskFlowImageInputSizeLimit(Object size) {
    return 'el límite de entrada de imagen de flujo de tareas ($size MiB)';
  }

  @override
  String taskFlowOcrInputTooLarge(Object limit) {
    return 'La imagen supera $limit. Elija una imagen más pequeña e inténtelo de nuevo.';
  }

  @override
  String get ocrTemplatePlainTextLabel => 'Texto sin formato';

  @override
  String get ocrTemplatePlainTextContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página, conservando los saltos de línea y los párrafos. Devuelve sólo texto sin formato; no agregue explicaciones o inferencias.';

  @override
  String get ocrTemplateMarkdownLabel => 'Reducción';

  @override
  String get ocrTemplateMarkdownContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página y utiliza Markdown para conservar títulos, listas y tablas. Representar fórmulas matemáticas en LaTeX. Devuelve sólo la transcripción; no agregue explicaciones o inferencias.';

  @override
  String get ocrTemplateTableLabel => 'Mesas';

  @override
  String get ocrTemplateTableContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página. Para las tablas, conserve los encabezados, las relaciones de filas y columnas, y las celdas vacías, y generelos como tablas Markdown. Mantenga el resto del contenido como texto normal. Devuelve sólo la transcripción; no agregue explicaciones o inferencias.';

  @override
  String get ocrTemplateLatexLabel => 'Látex';

  @override
  String get ocrTemplateLatexContent =>
      'Transcribe todo el texto visible en el orden de lectura natural de la página. Preservar texto sin fórmulas y representar fórmulas matemáticas en LaTeX; use \$...\$ para fórmulas en línea y \$\$...\$\$ para fórmulas de visualización. Devuelve sólo la transcripción; no agregue explicaciones o inferencias.';

  @override
  String get ocrDefaultImagesOnly => 'Predeterminado (enviar solo imágenes)';

  @override
  String get ocrDefaultSystemPrompt =>
      'Extraiga todo el texto de la imagen, conservando su formato y diseño originales. Devuelve sólo el texto extraído; No agregues ninguna explicación.';

  @override
  String get ocrSavedInstructionSnapshot =>
      'Instantánea de instrucciones guardadas';

  @override
  String get ocrPageTitle => 'Reconocimiento de texto de imagen';

  @override
  String get ocrImageQualitySettings => 'Configuración de calidad de imagen';

  @override
  String get ocrImageQualityStandard => 'Calidad estándar';

  @override
  String get ocrImageQualityStandardHint =>
      'Imágenes más pequeñas para la mayoría de los casos de uso';

  @override
  String get ocrImageQualityOriginal => 'Original/alto detalle';

  @override
  String get ocrImageQualityOriginalHint =>
      'Mantiene más detalles; Las imágenes y las solicitudes son más grandes.';

  @override
  String get ocrReorderDone => 'Hecho';

  @override
  String get ocrReorderAction => 'Reordenar';

  @override
  String get ocrClearAction => 'Limpiar';

  @override
  String ocrLegacyModelHint(Object modelId) {
    return 'La tarea anterior utilizó el modelo $modelId. Elija nuevamente un proveedor y modelo.';
  }

  @override
  String get ocrLegacyModelPositionInvalid =>
      'La posición del modelo en el registro de reintento anterior no es válida. Elige un modelo nuevamente.';

  @override
  String get ocrLegacyModelPositionConfirm =>
      'El registro de reintento anterior guardó solo la posición del modelo. Confirme el modelo actual antes de continuar.';

  @override
  String get ocrModelUnavailable =>
      'El proveedor o modelo de OCR original ya no está disponible. Elige otro.';

  @override
  String get ocrModelLabel => 'Modelo';

  @override
  String get ocrConfigure => 'Configurar';

  @override
  String get ocrSelectModel => 'Selecciona un modelo';

  @override
  String get ocrInstructionLabel => 'Instrucción';

  @override
  String get ocrManageInstructions =>
      'Gestionar instrucciones de reconocimiento';

  @override
  String get ocrInstructionManageGuidance =>
      'Estas instrucciones se aplican a todos los modelos de reconocimiento. Si no se selecciona ninguno, solo se envía la imagen.';

  @override
  String get ocrInstructionManageEmpty => 'Aún no hay instrucciones';

  @override
  String get ocrInstructionEditTooltip => 'Editar instrucción';

  @override
  String get ocrInstructionDeleteTooltip => 'Eliminar instrucción';

  @override
  String get ocrInstructionAdd => 'Agregar instrucción';

  @override
  String get ocrInstructionEditorEditTitle => 'Editar instrucción';

  @override
  String get ocrInstructionNameLabel => 'Nombre de la instrucción (opcional)';

  @override
  String get ocrInstructionContentLabel => 'Contenido de la instrucción';

  @override
  String get ocrBatchMode => 'Modo por lotes';

  @override
  String get ocrMergeRecognition => 'Combinar resultados';

  @override
  String get ocrRecognizeEachImage => 'Reconocer cada imagen por separado';

  @override
  String get ocrMaxConcurrency => 'Hasta 2 solicitudes simultáneas';

  @override
  String ocrConcurrencyOption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes simultáneas',
      one: '$count solicitud simultánea',
    );
    return '$_temp0';
  }

  @override
  String ocrConcurrencyStatus(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solicitudes simultáneas',
      one: '$count solicitud simultánea',
    );
    return '$_temp0';
  }

  @override
  String get ocrRetryCompletedHint =>
      'Las páginas completadas se conservan; reintentar envía sólo páginas sin terminar.';

  @override
  String get ocrTakePhoto => 'tomar una foto';

  @override
  String get ocrChooseFromAlbum => 'Elige del álbum';

  @override
  String get ocrNoImagesSelected => 'No hay imágenes seleccionadas';

  @override
  String get ocrSelectImagesHint =>
      'Tome una foto o seleccione varias imágenes de su álbum para reconocerlas.';

  @override
  String ocrRechooseRequiredImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'las imágenes requeridas',
      one: 'la imagen requerida',
    );
    return 'Vuelve a seleccionar $_temp0 antes de reintentar.';
  }

  @override
  String ocrImageLabel(Object index) {
    return 'Imagen $index';
  }

  @override
  String ocrImageFileName(Object format, Object index) {
    return 'Imagen_$index.$format';
  }

  @override
  String get ocrPreviewInvalidIndex => 'Índice de imagen no válido';

  @override
  String get ocrViewErrorDetails => 'Ver detalles del error';

  @override
  String get ocrConfirmModel => 'Confirmar este modelo';

  @override
  String ocrSelectedImagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imágenes seleccionadas',
      one: '$count imagen seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get ocrPreparingImages => 'Preparando imágenes…';

  @override
  String get ocrSavingRetryImages => 'Guardando imágenes de reintento…';

  @override
  String get ocrRecognizing => 'Reconociendo…';

  @override
  String get ocrReadingRetryImages => 'Leyendo imágenes de reintento…';

  @override
  String get ocrImportingImages => 'Importando imágenes…';

  @override
  String get ocrStartRecognition => 'Iniciar reconocimiento';

  @override
  String get ocrSaveTo => 'Guardar en';

  @override
  String get ocrRootDirectory => 'directorio raíz';

  @override
  String get ocrChooseSaveFolder => 'Elija una carpeta para guardar';

  @override
  String get ocrChooseImageSource => 'Elige la fuente de la imagen';

  @override
  String get ocrChooseAppAlbum => 'Elija del álbum de aplicaciones';

  @override
  String get ocrAppAlbumDescription =>
      'Elija imágenes ya guardadas en la aplicación';

  @override
  String get ocrChooseSystemAlbum => 'Elija del álbum del sistema';

  @override
  String get ocrSystemAlbumDescription =>
      'Explora y elige imágenes en este dispositivo';

  @override
  String ocrTakePhotoFailed(Object error) {
    return 'Error al tomar la foto: $error';
  }

  @override
  String ocrChooseImageFailed(Object error) {
    return 'Error al seleccionar la imagen: $error';
  }

  @override
  String ocrImagesLoaded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se cargaron $count imágenes',
      one: 'Se cargó $count imagen',
    );
    return '$_temp0';
  }

  @override
  String ocrProcessImageFailed(Object error) {
    return 'Error al procesar la imagen: $error';
  }

  @override
  String get ocrUnknownSourceImageCount =>
      'No se puede determinar el recuento de imágenes originales';

  @override
  String get ocrConfirmClear => 'Confirmar claro';

  @override
  String get ocrRetryUnavailableConfirmClear =>
      'La caché de imágenes OCR original no está disponible y su recuento de imágenes no se puede recuperar. Al borrarlo se restablecerá el estado de reintento anterior. Seleccione todas las imágenes para esta tarea de OCR nuevamente.';

  @override
  String get ocrConfirmClearSelected =>
      '¿Borrar las imágenes OCR seleccionadas?';

  @override
  String get ocrCancel => 'Cancelar';

  @override
  String get ocrConfirmResetAndReselect =>
      'Restablecer y seleccionar imágenes nuevamente';

  @override
  String get ocrRequestCheckFailed =>
      'No se puede verificar la solicitud de OCR. Verifique los parámetros del modelo.';

  @override
  String get ocrCancelledAdjustAndRetry =>
      'Se canceló el reconocimiento. Ajuste el tamaño de la solicitud de proveedor/modelo o la calidad de la imagen y vuelva a intentarlo.';

  @override
  String get ocrRequestSizeExceededTitle =>
      'La solicitud de OCR excede el tamaño configurado';

  @override
  String ocrRequestSizeExceededBody(Object limit, Object requestSize) {
    return 'La solicitud es sobre $requestSize MiB, que excede el límite de MiB $limit configurado.';
  }

  @override
  String get ocrRequestSizeHelp =>
      'Ajuste el tamaño de la solicitud en los valores predeterminados del proveedor o en las anulaciones de modelos, o elija una calidad de imagen diferente. Después de cambiar la calidad, borre e importe las imágenes nuevamente.';

  @override
  String get ocrUsePerImageMode => 'Utilice el reconocimiento por imagen';

  @override
  String get ocrGotIt => 'Entiendo';

  @override
  String get ocrWaitForImport =>
      'Espere a que finalice la importación de la imagen antes de comenzar el reconocimiento.';

  @override
  String get ocrWaitForRetryImages =>
      'Lectura de imágenes de reintento. Espere por favor.';

  @override
  String get ocrConfigureProviderModel =>
      'Configure primero un proveedor y un modelo de OCR en Configuración.';

  @override
  String get ocrReselectProviderModel =>
      'Seleccione nuevamente un proveedor y modelo de OCR.';

  @override
  String get ocrConfirmLegacyModel =>
      'Primero confirme el modelo de OCR del registro de reintento anterior.';

  @override
  String get ocrRetryImagesUnavailable =>
      'La caché de imágenes OCR original no está disponible. Borre la tarea y seleccione todas las imágenes nuevamente.';

  @override
  String get ocrRetryImageCountUnknown =>
      'La caché de imágenes OCR original no está disponible y se desconoce su recuento de imágenes. Restablezca y seleccione todas las imágenes para esta tarea de OCR nuevamente.';

  @override
  String get ocrRetryImageReset =>
      'Se restableció la entrada de reintento anterior. Seleccione todas las imágenes para esta tarea de OCR nuevamente.';

  @override
  String get ocrRetryImagesUnreadable =>
      'No se pudo leer el caché de imagen OCR original. Borre la tarea y seleccione todas las imágenes nuevamente.';

  @override
  String get ocrRetryImagesMissing =>
      'La memoria caché de la imagen OCR original falta o está dañada. Borre la tarea y seleccione todas las imágenes nuevamente.';

  @override
  String get ocrImageListChanged =>
      'La lista de imágenes cambió. Inicie el reconocimiento nuevamente.';

  @override
  String get ocrReadInstructionFailed =>
      'No se pueden leer las instrucciones de reconocimiento. Intentar otra vez.';

  @override
  String get ocrErrorDetails => 'Detalles del error';

  @override
  String get ocrRequestHeading => 'Pedido';

  @override
  String get ocrResponseHeading => 'Respuesta';

  @override
  String get ocrNoDetails => 'No hay detalles disponibles';

  @override
  String get ocrImageLoadFailed => 'No se puede cargar la imagen';

  @override
  String get ocrCrop => 'Cultivo';

  @override
  String get ocrEdit => 'Editar';

  @override
  String get ocrProcessingOcrFailed =>
      'No se pudieron procesar las imágenes OCR. Por favor inténtalo de nuevo.';

  @override
  String get settingsPageTitle => 'Ajustes';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsSectionProviders => 'Proveedores';

  @override
  String get settingsSectionSystemAssistant => 'Asistentes del sistema';

  @override
  String get settingsSectionContextManagement => 'Gestión del contexto';

  @override
  String get settingsSectionManagement => 'Gestión';

  @override
  String get settingsSectionAbout => 'Acerca de';

  @override
  String get settingsBackupRestore => 'Copia de seguridad y restauración';

  @override
  String get settingsBackupRestoreDescription =>
      'Exportar o importar datos de aplicaciones';

  @override
  String get settingsCookies => 'Cookies y datos del navegador';

  @override
  String get settingsCookiesDescription =>
      'Administrar cookies persistentes y almacenamiento del navegador';

  @override
  String get settingsAppLogs => 'Registros de aplicaciones';

  @override
  String get settingsAppLogsDescription =>
      'Ver registros de tiempo de ejecución de la aplicación';

  @override
  String get settingsThemeDisplay => 'Tema y visualización';

  @override
  String get settingsThemeDisplayDescription =>
      'Modo oscuro e idioma de visualización';

  @override
  String get settingsTaskNotifications =>
      'Notificaciones de finalización de tareas';

  @override
  String get settingsTaskNotificationsDescription =>
      'Verifique el permiso de notificación y la configuración del sistema, y ​​vea la guía de notificación';

  @override
  String get settingsBackgroundOptimization =>
      'Optimización de la operación en segundo plano';

  @override
  String get settingsBackgroundOptimizationDescription =>
      'Verifique el entorno del sistema y el estado del servicio en segundo plano, y vea la guía de optimización';

  @override
  String get aboutVersionInfo => 'Ver información de la versión';

  @override
  String get aboutCheckUpdates => 'Buscar actualizaciones';

  @override
  String aboutNewVersionFound(Object version) {
    return 'Nueva versión $version disponible';
  }

  @override
  String get aboutNewVersion => 'Nueva versión';

  @override
  String get aboutPreviewUpdates => 'Vista previa de actualizaciones';

  @override
  String get aboutPreviewUpdatesDescription =>
      'Habilitar comprobaciones para versiones preliminares';

  @override
  String get aboutProjectHome => 'Inicio del proyecto';

  @override
  String get aboutFeedback => 'Informar un problema';

  @override
  String get aboutPrivacyPolicy => 'política de privacidad';

  @override
  String get aboutOpenSourceAgreement => 'Acuerdo de código abierto';

  @override
  String get aboutOpenSourceLicenses => 'Licencias de código abierto';

  @override
  String get aboutCheckingUpdates => 'Buscando actualizaciones...';

  @override
  String get aboutUpToDate => 'Estás usando la última versión.';

  @override
  String aboutUpdateNetworkError(Object details) {
    return 'Error de red: $details';
  }

  @override
  String aboutUpdateHttpError(Object statusCode) {
    return 'La verificación de actualización falló con el estado HTTP $statusCode.';
  }

  @override
  String get aboutUpdateInvalidResponse =>
      'El servidor de actualización arrojó una respuesta inesperada.';

  @override
  String get aboutUpdateCheckFailed =>
      'La verificación de actualización falló. Por favor inténtalo de nuevo.';

  @override
  String topicAssistantUpdateCheckFailed(Object error) {
    return 'Error en la comprobación de actualización del asistente: $error';
  }

  @override
  String get aboutPrivacyContent =>
      'Stroom respeta y protege la privacidad de todos los que utilizan el servicio.\n\n1. Permiso de cámara: Se utiliza únicamente para tomar fotografías. No se recopilan ni cargan datos de imágenes.\n\n2. Permiso de la biblioteca de fotografías: Se utiliza únicamente para elegir y guardar fotografías. Todas las fotos se almacenan localmente en su dispositivo.\n\n3. Seguridad de los datos: todas las fotos que toma se almacenan localmente en su dispositivo. No accedemos ni subimos sus datos.\n\n4. Servicios de terceros: esta aplicación no contiene servicios de publicidad ni análisis de terceros.\n\nContáctenos si tiene preguntas.';

  @override
  String get aboutClose => 'Cerrar';

  @override
  String get contextToolPruneTitle =>
      'Podar automáticamente los resultados de la herramienta (Prune)';

  @override
  String get contextToolPruneDescription =>
      'Reemplace automáticamente los resultados de herramientas antiguas que superen el umbral con marcadores de posición para liberar almacenamiento y contexto.';

  @override
  String get contextCompactionTriggerSettings =>
      'Configuración del activador de compactación';

  @override
  String get contextCompactionDisabled =>
      'Deshabilitado (la compactación no se ejecutará)';

  @override
  String contextGlobalTriggerPercent(Object percent) {
    return 'Activador global $percent%';
  }

  @override
  String contextModelOverrideCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anulaciones específicas del modelo',
      one: '$count anulación específica del modelo',
    );
    return '$_temp0';
  }

  @override
  String get contextCompressionTriggerTitle =>
      'Configuración del activador de compactación';

  @override
  String get contextAutoCompaction => 'Compactación automática de contexto';

  @override
  String get contextAutoCompactionDisabled =>
      'Cuando está deshabilitado, la compactación no se ejecutará para ningún modelo.';

  @override
  String get contextGlobalTrigger => 'Porcentaje de activación global';

  @override
  String get contextGlobalTriggerDescription =>
      'Los modelos sin una configuración individual utilizan este porcentaje de la ventana de contexto del modelo como activador de compactación.';

  @override
  String contextResetPercent(Object percent) {
    return 'Restablecer a $percent%';
  }

  @override
  String get contextPerModelSettings => 'Configuración por modelo';

  @override
  String get contextNoConfiguredModels => 'No hay modelos configurados';

  @override
  String contextIndependentThreshold(Object threshold) {
    return 'Umbral independiente: tokens $threshold';
  }

  @override
  String get contextEnterIndependentThreshold =>
      'Introduzca un umbral independiente a continuación';

  @override
  String contextFollowGlobalPercent(Object percent) {
    return 'Seguir global $percent%';
  }

  @override
  String get contextThresholdField => 'Umbral independiente (tokens)';

  @override
  String get contextThresholdHint =>
      'Por ejemplo, 48000 (recuento de tokens, no porcentaje)';

  @override
  String get contextPercentField => 'Porcentaje';

  @override
  String contextPercentHint(Object percent) {
    return 'Por ejemplo, $percent';
  }

  @override
  String get versionInfoTitle => 'Información de versión';

  @override
  String get versionNumberLabel => 'Versión';

  @override
  String get versionReleaseTimeLabel => 'tiempo de liberación';

  @override
  String get versionLocalBuild => 'Construcción local';

  @override
  String get versionReleaseNotesLabel => 'Notas de la versión';

  @override
  String get versionClose => 'Cerrar';

  @override
  String get updateDialogTitle => 'Nueva versión disponible';

  @override
  String get updateLatestVersionLabel => 'Última versión';

  @override
  String get updateSelectedVersionLabel => 'Versión seleccionada';

  @override
  String get updateReleaseNotesLabel => 'Notas de la versión';

  @override
  String get updateInstalling => 'Instalando…';

  @override
  String get updateDownloadComplete => 'Descarga completa';

  @override
  String get updateClose => 'Cerrar';

  @override
  String get updateManualInstall => 'Instalar manualmente';

  @override
  String get updateOpenInstaller => 'Abrir instalador';

  @override
  String get updateRetryDownload => 'Reintentar descargar';

  @override
  String get updateSkipVersion => 'Saltar esta versión';

  @override
  String get updateRemindLater => 'Recuérdamelo más tarde';

  @override
  String get updateOpenBrowser => 'Descargar en el navegador';

  @override
  String get updateNow => 'Actualizar ahora';

  @override
  String get updatePreviewBadge => 'Avance';

  @override
  String get updateLatestBadge => 'El último';

  @override
  String get updateSelectVersion => 'Seleccionar versión';

  @override
  String get updateDownloading => 'Descargando actualización…';

  @override
  String updateCheckNetworkError(Object details) {
    return 'Error de red: $details';
  }

  @override
  String updateCheckHttpFailed(Object statusCode) {
    return 'No se pudieron buscar actualizaciones: HTTP $statusCode';
  }

  @override
  String get updateCheckInvalidResponse =>
      'No se pudieron buscar actualizaciones: el servidor devolvió datos no reconocidos';

  @override
  String get updateDownloadUrlUnavailable =>
      'La URL de descarga no está disponible.';

  @override
  String get updateNoDirectDownloadLink =>
      'No existe un enlace de descarga directa para esta plataforma. Descárgalo en un navegador.';

  @override
  String updateAutomaticInstallFailed(Object details) {
    return 'La instalación automática falló: $details';
  }

  @override
  String updateDownloadHttpFailed(Object statusCode) {
    return 'Error de descarga: HTTP $statusCode';
  }

  @override
  String updateDownloadFailed(Object details) {
    return 'Descarga fallida: $details';
  }

  @override
  String updateInstallFailed(Object details) {
    return 'Error de instalación: $details';
  }

  @override
  String updateFailed(Object details) {
    return 'Error en la actualización: $details';
  }

  @override
  String updateManualInstallFileError(Object path) {
    return 'No se pudo abrir el archivo. Instálelo manualmente: $path';
  }

  @override
  String updateApkInstallFailed(Object details) {
    return 'La instalación falló. Abra el APK manualmente: $details';
  }

  @override
  String get updateApkInstallFailedNoDetails =>
      'La instalación falló. Abra el APK manualmente.';

  @override
  String get updateApkInstallerUnavailable =>
      'No se pudo encontrar una aplicación para instalar este APK. Ábrelo manualmente.';

  @override
  String get updateApkInstallPermissionDenied =>
      'Permita que Stroom instale aplicaciones desconocidas en la configuración del sistema.';

  @override
  String get updateRestartDialogTitle => 'Aplicación actualizada';

  @override
  String get updateRestartDialogBody =>
      'La aplicación ha sido actualizada. Reinicie la aplicación para garantizar la estabilidad.';

  @override
  String get updateRestartDialogLater => 'Reiniciar más tarde';

  @override
  String get updateRestartDialogNow => 'Reiniciar ahora';

  @override
  String get contextCompactionHistoryIntro =>
      'Historial de conversaciones para condensar:';

  @override
  String get contextCompactionUserRole => 'Usuario';

  @override
  String get contextCompactionAssistantRole => 'Asistente';

  @override
  String contextCompactionToolCall(
    Object result,
    Object role,
    Object toolName,
  ) {
    return '$role herramienta llamada $toolName: $result';
  }

  @override
  String get contextCompactionFinalInstruction =>
      'Condense el historial de conversaciones anterior en un resumen anclado, siguiendo exactamente la plantilla.';

  @override
  String get ocrImageEmpty => 'La imagen está vacía. Selecciónelo nuevamente.';

  @override
  String get ocrImageUnsupportedFormat =>
      'Este formato de imagen no es compatible. Conviértelo a PNG, JPEG o WebP e inténtalo de nuevo.';

  @override
  String get ocrImageUnsupportedSpecialFormat =>
      'Las imágenes HEIC, SVG y TIFF aún no son compatibles. Convierta la imagen a PNG, JPEG o WebP e inténtelo de nuevo.';

  @override
  String get ocrImageDecodeFailed =>
      'La imagen está dañada o no se puede decodificar. Selecciónelo nuevamente o conviértalo a PNG, JPEG o WebP e inténtelo nuevamente.';

  @override
  String get ocrImageDimensionsTooLarge =>
      'La resolución de la imagen es demasiado grande. OCR admite hasta 50 millones de píxeles por imagen. Cambie su tamaño e inténtelo de nuevo.';

  @override
  String get ocrImageOrientationPngTooLarge =>
      'El PNG necesario para corregir la orientación de esta imagen excedería el límite de tamaño de la solicitud de OCR. Cambie el tamaño de la imagen e inténtelo de nuevo.';

  @override
  String get ocrImageOrientationFailed =>
      'No se pudo corregir la orientación de la imagen. Conviértelo a PNG, JPEG o WebP e inténtalo de nuevo.';

  @override
  String get ocrImagePreparationFailed =>
      'La imagen no se pudo procesar. Selecciónelo nuevamente e inténtelo nuevamente.';

  @override
  String get homeTitle => 'Hogar';

  @override
  String get homeWelcome => 'Bienvenido a Stroom';

  @override
  String get homeChooseModule => 'Elija un módulo para comenzar';

  @override
  String get homeOcrSubtitle => 'Reconocimiento de texto';

  @override
  String get homeAsrTitle => 'reconocimiento de voz';

  @override
  String get homeAsrSubtitle => 'Discurso a texto';

  @override
  String get homeWebDownloadTitle => 'Descargar medios web';

  @override
  String get homeWebDownloadSubtitle =>
      'Descargar audio y vídeo de páginas web.';

  @override
  String get homeAudioSeparationTitle => 'Separación de audio';

  @override
  String get homeAudioSeparationSubtitle => 'Extraer audio de vídeo';

  @override
  String get homeTtsTitle => 'Texto a voz';

  @override
  String get homeTtsSubtitle => 'Convertir texto a voz';

  @override
  String get homeChartsTitle => 'Creador de gráficos';

  @override
  String get homeChartsSubtitle => 'Editor de gráficos de sirena';

  @override
  String get homeMathTitle => 'trazado matemático';

  @override
  String get homeMathSubtitle => 'Funciones de trazado';

  @override
  String get homeAnkiTitle => 'Tarjetas didácticas de Anki';

  @override
  String get homeAnkiSubtitle => 'Sistema de ayuda a la memoria';

  @override
  String get homeTaskFlowTitle => 'Flujos de tareas';

  @override
  String get homeTaskFlowEmpty =>
      'Cree un flujo automatizado para ejecutar varios módulos en secuencia';

  @override
  String homeTaskFlowManage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count flujos de tareas · Administrar',
      one: '$count flujo de tareas · Administrar',
    );
    return '$_temp0';
  }

  @override
  String get homeRecentTasks => 'Tareas recientes';

  @override
  String get homeViewAll => 'Ver todo';

  @override
  String get statusInProgress => 'En curso';

  @override
  String get statusCompleted => 'Terminado';

  @override
  String get statusFailed => 'Fallido';

  @override
  String get navHome => 'Hogar';

  @override
  String get navChat => 'Charlar';

  @override
  String get navFiles => 'Archivos';

  @override
  String get navSettings => 'Ajustes';

  @override
  String get conversationsTitle => 'Historial de conversaciones';

  @override
  String get conversationNew => 'Nueva conversación';

  @override
  String get conversationSelectTitle => 'Elige una conversación';

  @override
  String get topicSelectionEmptyTitle => 'Aún no hay conversaciones';

  @override
  String get topicSelectionEmptyMessage =>
      'Crea una nueva conversación para comenzar';

  @override
  String get topicSelectionNewTopic => 'Nueva conversación';

  @override
  String get topicSelectionNoAssistant => 'Ningún asistente seleccionado';

  @override
  String get topicSelectionBackToAssistants =>
      'Volver a la selección de asistente';

  @override
  String get topicSelectionEditAssistant => 'Asistente de edición';

  @override
  String get topicSelectionReorderHint =>
      'Mantenga presionado y arrastre para reordenar las conversaciones';

  @override
  String conversationDeleteNamed(String title) {
    return '¿Eliminar la conversación “$title”? Esto no se puede deshacer.';
  }

  @override
  String get conversationDeleteTitle => 'Eliminar conversación';

  @override
  String conversationDeleteMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '¿Eliminar las conversaciones seleccionadas ($count)? Esta acción no se puede deshacer.',
      one:
          '¿Eliminar la conversación seleccionada ($count)? Esta acción no se puede deshacer.',
    );
    return '$_temp0';
  }

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionDelete => 'Borrar';

  @override
  String get conversationRename => 'Cambiar el nombre de la conversación';

  @override
  String get conversationRenameHint => 'Introduzca un nuevo nombre';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get conversationNoMatches =>
      'No se encontraron conversaciones coincidentes';

  @override
  String get conversationEmpty => 'Sin historial de conversaciones';

  @override
  String get conversationSearchHint =>
      'Buscar mensajes en todas las conversaciones...';

  @override
  String conversationSelected(int count) {
    return '$count seleccionado';
  }

  @override
  String get conversationSearch => 'Buscar';

  @override
  String get conversationDeleteSelected => 'Eliminar seleccionado';

  @override
  String get actionUnselect => 'Cancelar selección';

  @override
  String get actionSelect => 'Seleccionar';

  @override
  String conversationDeleteCount(int count) {
    return 'Eliminar $count';
  }

  @override
  String get conversationPin => 'Alfiler';

  @override
  String get conversationUnpin => 'Desprender';

  @override
  String get actionRename => 'Rebautizar';

  @override
  String get conversationAutoRename => 'Nombre automático';

  @override
  String get conversationTemporary => 'conversación temporal';

  @override
  String get conversationCloseTemporary => 'Cerrar conversación temporal';

  @override
  String get taskListTitle => 'lista de tareas';

  @override
  String get taskListEmpty => 'Sin tareas';

  @override
  String get unifiedTaskListTabAll => 'Todo';

  @override
  String get unifiedTaskListTabInProgress => 'En curso';

  @override
  String get unifiedTaskListTabCompleted => 'Terminado';

  @override
  String get unifiedTaskListTabFailed => 'Fallido';

  @override
  String get unifiedTaskListTabStopped => 'Interrumpido';

  @override
  String get unifiedTaskListConfirmClear => 'Confirmar claro';

  @override
  String get unifiedTaskListConfirmClearFailedMessage =>
      '¿Está seguro de que desea borrar todas las tareas fallidas?';

  @override
  String get unifiedTaskListConfirmClearAllMessage =>
      '¿Estás seguro de que deseas borrar todas las tareas? Esta acción no se puede deshacer.';

  @override
  String get unifiedTaskListCancel => 'Cancelar';

  @override
  String get unifiedTaskListConfirm => 'Confirmar';

  @override
  String get unifiedTaskListClearCompleted => 'Borrar tareas completadas';

  @override
  String get unifiedTaskListClearFailed => 'Borrar tareas fallidas';

  @override
  String get unifiedTaskListClearAll => 'Borrar todas las tareas';

  @override
  String get unifiedTaskListRestoreInProgress =>
      'Restaurando registros de flujo de tareas...';

  @override
  String get unifiedTaskListRestoreFailed =>
      'No se pudieron leer los registros de flujo de tareas; las acciones de la tarea están en pausa';

  @override
  String unifiedTaskListClearIncomplete(String error) {
    return 'Borrar incompleto: $error';
  }

  @override
  String get unifiedTaskListCancellationStillRunning =>
      'El flujo de tareas sigue ejecutándose después de la cancelación.';

  @override
  String get unifiedTaskListCancellationSaveFailed =>
      'No se pudo guardar el estado de cancelación del flujo de tareas. Vuelva a intentar borrar.';

  @override
  String get unifiedTaskListRemovalSaveFailed =>
      'No se pudo guardar la eliminación de registros de flujo de tareas. Vuelva a intentar borrar.';

  @override
  String get chatAutoContinuePrompt => 'Continúe si no ha terminado.';

  @override
  String get chatSearchCurrent => 'Buscar esta conversación...';

  @override
  String get chatSearchAll => 'Buscar todas las conversaciones...';

  @override
  String get searchPrevious => 'Partido anterior';

  @override
  String get searchNext => 'Próximo partido';

  @override
  String get searchClose => 'Cerrar búsqueda';

  @override
  String get searchCurrentConversation => 'Conversación actual';

  @override
  String get searchAllConversations => 'Todas las conversaciones';

  @override
  String get chatReasoning => 'Razonamiento';

  @override
  String get chatTools => 'Herramientas';

  @override
  String get chatCustomParameters => 'Parámetros personalizados';

  @override
  String get chatEditMessage => 'Editar mensaje';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get chatEditWarning =>
      'Todos los mensajes a continuación se perderán cuando los edites y los reenvíes.';

  @override
  String get chatAttachment => 'Adjunto';

  @override
  String get chatMessageHint => 'Introduce un mensaje...';

  @override
  String get chatFullscreenEdit => 'Editor de pantalla completa';

  @override
  String get chatStopGeneration => 'dejar de generar';

  @override
  String get actionSend => 'Enviar';

  @override
  String get chatCopy => 'Copiar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionRetry => 'Rever';

  @override
  String get actionEdit => 'Editar';

  @override
  String get chatViewResponseData => 'Ver datos de respuesta';

  @override
  String get chatViewRequestData => 'Ver datos de la solicitud';

  @override
  String get chatInspectJson => 'Inspeccionar JSON';

  @override
  String get chatConfirmEditTitle => 'Editar mensaje';

  @override
  String get chatConfirmEditDeleteFollowing =>
      '¿Editar este mensaje? Este mensaje y todos los mensajes siguientes serán eliminados.';

  @override
  String get chatConfirmResend => '¿Reenviar este mensaje?';

  @override
  String get chatConfirmRetryTitle => 'Rever';

  @override
  String get chatConfirmRetryDeleteFollowing =>
      '¿Reintentar esta respuesta? Este mensaje y todos los mensajes siguientes serán eliminados.';

  @override
  String get chatConfirmRegenerate => '¿Regenerar la respuesta?';

  @override
  String get chatDeleteMessageTitle => 'Eliminar mensaje';

  @override
  String get chatDeleteMessageConfirm =>
      '¿Eliminar este mensaje? Esto no se puede deshacer.';

  @override
  String get chatThinking => 'Pensamiento';

  @override
  String get chatThinkingComplete => 'Pensamiento';

  @override
  String get conversationDeleteOne =>
      '¿Eliminar esta conversación? Esto no se puede deshacer.';

  @override
  String mediaSelectionCount(int selected, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Recursos $selected/$total seleccionados',
      one: 'Recurso $selected/$total seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get mediaSelectionTitle => 'Seleccione medios para descargar';

  @override
  String mediaCollapseSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ocultar $count segmentos',
      one: 'Ocultar $count segmento',
    );
    return '$_temp0';
  }

  @override
  String mediaExpandSegments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar $count segmentos',
      one: 'Mostrar $count segmento',
    );
    return '$_temp0';
  }

  @override
  String get mediaNoResources => 'No se detectaron recursos';

  @override
  String get mediaSegment => 'Segmento';

  @override
  String get mediaPlaylist => 'Lista de reproducción';

  @override
  String get mediaFullVideo => 'vídeo completo';

  @override
  String homeMediaDurationHoursMinutesSeconds(
    int hours,
    int minutes,
    int seconds,
  ) {
    return '$hours horas $minutes minutos $seconds segundos';
  }

  @override
  String mediaDuration(String value) {
    return 'Duración: $value';
  }

  @override
  String mediaResolution(int width, int height) {
    return 'Resolución: ${width}x$height';
  }

  @override
  String get mediaPreview => 'Avance';

  @override
  String get mediaSegmentPreviewHint =>
      'Vista previa de segmentos de la lista de reproducción';

  @override
  String mediaDownloadSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descargar $count recursos seleccionados',
      one: 'Descargar $count recurso seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get mediaConfirmDownload => 'Confirmar descarga';

  @override
  String get chatNoMoreHistory => 'No más mensajes';

  @override
  String get chatSendFailed => 'No se pudo enviar el mensaje';

  @override
  String get chatViewErrorDetails => 'Ver detalles del error';

  @override
  String get chatCompactionCollapsed =>
      'Contexto compactado · mensajes antiguos resumidos (haga clic para contraer)';

  @override
  String get chatCompactionExpanded =>
      'Contexto compactado · mensajes antiguos resumidos (haga clic para ver el resumen)';

  @override
  String get chatEditConversationTitle => 'Editar título de conversación';

  @override
  String get chatSearchMessages => 'Buscar mensajes';

  @override
  String get chatApiMissingSettings =>
      '⚠️ La API de chat no está configurada: ve a Configuración';

  @override
  String get appSettings => 'Ajustes';

  @override
  String get chatCopied => 'Copiado';

  @override
  String get chatNoSavableText => 'No hay texto para guardar';

  @override
  String get chatSaveMarkdownTitle => 'Guardar mensaje como Markdown';

  @override
  String get chatSaveToolCallChoice =>
      'Esta respuesta contiene varias llamadas a herramientas. Elige qué guardar:';

  @override
  String get chatSaveCompleteMessage => 'Guardar mensaje completo';

  @override
  String get chatSaveLastMessage => 'Guardar último mensaje';

  @override
  String get chatSaveToAppFiles => 'Guardar en archivos de aplicaciones';

  @override
  String get chatSaveFolderHint =>
      'Elija o cree una carpeta para el archivo .md';

  @override
  String get chatSaveFilenameHint =>
      'Ingrese un nombre de archivo (.md se agrega automáticamente)';

  @override
  String get chatFilenameRequired =>
      'El nombre del archivo no puede estar vacío.';

  @override
  String chatSavedToPath(String path) {
    return 'Guardado en: $path';
  }

  @override
  String chatSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String chatSavedToAppFiles(String path) {
    return 'Guardado en archivos de aplicación: $path';
  }

  @override
  String get chatSelectModel => 'Selecciona un modelo';

  @override
  String get chatModelFallback => 'Modelo';

  @override
  String get chatNoModelsAvailable => 'No hay modelos disponibles';

  @override
  String get chatAvailableTools => 'Herramientas disponibles';

  @override
  String get chatNoToolsAvailable => 'No hay herramientas disponibles';

  @override
  String get chatReasoningSettings => 'Configuración de razonamiento';

  @override
  String get chatReasoningNotConfigured =>
      'No hay parámetros de razonamiento configurados para este modelo. Agréguelos en la configuración del modelo.';

  @override
  String get chatReasoningEffort => 'esfuerzo de razonamiento';

  @override
  String get chatReasoningEffortNotConfigured =>
      'No hay ningún parámetro de esfuerzo de razonamiento configurado para este modelo. Agréguelo en la configuración del modelo.';

  @override
  String get chatParameterNoOptions =>
      'Este parámetro no tiene valores de opción. Agréguelos en la configuración del modelo.';

  @override
  String get chatOtherReasoningNotConfigured =>
      'No se configuran otros parámetros de razonamiento para este modelo.\nAgréguelos en la configuración del modelo.';

  @override
  String get chatCustomParamsNotConfigured =>
      'No hay parámetros personalizados configurados para este modelo.\nAgréguelos en la configuración del modelo.';

  @override
  String get chatNoOptionValues =>
      'Sin valores de opción. Agréguelos en la configuración del modelo.';

  @override
  String get chatImageLoadFailed => 'No se puede cargar la imagen';

  @override
  String get chatVideoLoadFailed => 'No se puede cargar el vídeo';

  @override
  String get chatHtmlLoading => 'Cargando vista previa HTML...';

  @override
  String get chatPreviewLoadFailed => 'No se pudo cargar la vista previa';

  @override
  String get albumPickerLoadFailed =>
      'No se puede cargar el álbum de la aplicación';

  @override
  String get chatHtmlPreview => 'Vista previa HTML';

  @override
  String get chatMermaidLoading => 'Cargando vista previa del gráfico...';

  @override
  String get chatMermaidPreview => 'Vista previa de sirena';

  @override
  String get chatZoomOut => 'alejar';

  @override
  String get chatZoomIn => 'Dar un golpe de zoom';

  @override
  String get chatJsonInspection => 'inspección JSON';

  @override
  String get chatNoRequestData => 'Sin datos de solicitud';

  @override
  String get chatNoResponseData => 'Sin datos de respuesta';

  @override
  String get chatSaveMessage => 'Guardar mensaje';

  @override
  String get chatChooseSaveLocation => 'Elige dónde guardar el mensaje';

  @override
  String get chatChooseSaveLocationLabel => 'Elija una ubicación para guardar:';

  @override
  String get chatSaveAppFile => 'Guardar en archivos de aplicaciones';

  @override
  String get chatSaveDevice => 'Guardar en dispositivo';

  @override
  String get chatFileTypeAudio => 'archivo de audio';

  @override
  String get chatFileTypeVideo => 'archivo de vídeo';

  @override
  String get chatFileTypeDocument => 'Documento';

  @override
  String get chatFileTypeGeneric => 'Archivo';

  @override
  String get chatInfoType => 'Tipo';

  @override
  String get chatInfoSize => 'Tamaño';

  @override
  String get chatInfoPath => 'Camino';

  @override
  String get chatErrorBack => 'Atrás';

  @override
  String get chatErrorPrefix => 'Error:';

  @override
  String get chatErrorCancelled => 'La salida fue interrumpida por el usuario.';

  @override
  String get chatErrorProviderNotConfigured =>
      'La API de chat no está configurada. Abra Configuración para configurar un proveedor.';

  @override
  String get chatErrorApiKeyNotConfigured =>
      'La clave API no está configurada. Verifique la configuración.';

  @override
  String get chatErrorServerConnection =>
      'No se puede conectar con el servidor. Verifique su conexión de red y dirección API.';

  @override
  String get chatErrorNetworkConnection =>
      'La conexión de red falló. Verifique su conexión de red.';

  @override
  String get chatErrorTimeout =>
      'Se agotó el tiempo de conexión. El servidor no respondió.';

  @override
  String chatAttachmentImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String chatAttachmentCameraFailed(String error) {
    return 'No se pudo tomar una foto: $error';
  }

  @override
  String chatAttachmentGalleryUnsupportedPlatform(
    String platform,
    String error,
  ) {
    return '$platform no admite el acceso a la galería del dispositivo: $error';
  }

  @override
  String get chatAttachmentWebPlatform => 'navegador web';

  @override
  String get chatAttachmentCurrentPlatform => 'este dispositivo';

  @override
  String get chatAttachmentGalleryPermissionHint =>
      'Conceda permiso de acceso a la biblioteca de fotografías e inténtelo de nuevo.';

  @override
  String get chatAttachmentBrowserPermissionHint =>
      'Permita que este sitio web acceda a archivos en la configuración de su navegador.';

  @override
  String get chatAttachmentGalleryFallbackHint =>
      'Verifique que su dispositivo admita la selección de galería.';

  @override
  String chatAttachmentImageImportFailed(String error, String userHint) {
    return 'No se pudo importar la imagen: $error\n$userHint';
  }

  @override
  String chatAttachmentFileUnsupportedPlatform(String platform, String error) {
    return '$platform no admite la selección de archivos: $error';
  }

  @override
  String get chatAttachmentFilePermissionHint =>
      'Conceda permiso de acceso al archivo e inténtelo de nuevo.';

  @override
  String get chatAttachmentFileFallbackHint =>
      'Verifique que su dispositivo admita la selección de archivos.';

  @override
  String chatAttachmentFileImportFailed(String error, String userHint) {
    return 'No se pudo importar el archivo: $error\n$userHint';
  }

  @override
  String chatAttachmentImported(String fileName) {
    return 'Importado $fileName';
  }

  @override
  String chatAttachmentEditedImageSaveFailed(String error) {
    return 'No se pudo guardar la imagen editada: $error';
  }

  @override
  String get chatDataDetails => 'Detalles de datos';

  @override
  String get chatErrorDetailOcrDiagnostics => 'Diagnóstico OCR';

  @override
  String get chatErrorDetailRequestUrl => 'Solicitar URL';

  @override
  String get chatErrorDetailRequestHeaders => 'Encabezados de solicitud';

  @override
  String get chatErrorDetailRequestBody => 'Cuerpo de solicitud';

  @override
  String get chatErrorDetailStatusCode => 'Código de estado';

  @override
  String get chatErrorDetailResponseHeaders => 'Encabezados de respuesta';

  @override
  String get chatErrorDetailResponseBody => 'Cuerpo de respuesta';

  @override
  String get chatErrorDetailEmpty => 'No hay datos detallados disponibles';

  @override
  String get chatAudioPreviewClose => 'Cerrar';

  @override
  String get chatPreviewClose => 'Cerrar vista previa';

  @override
  String get actionBack => 'Atrás';

  @override
  String get chatCannotLoadFile => 'No se puede cargar el archivo';

  @override
  String chatThinkingNumbered(int index) {
    return 'Pensando $index';
  }

  @override
  String get taskFlowUiDiscardTitle => '¿Descartar los cambios no guardados?';

  @override
  String get taskFlowUiDiscardBody =>
      'Todos los cambios no guardados se perderán si regresa.';

  @override
  String get taskFlowUiContinueEditing => 'Continuar editando';

  @override
  String get taskFlowUiDiscard => 'Desechar';

  @override
  String get taskFlowUiUndo => 'Deshacer';

  @override
  String get taskFlowUiSave => 'Guardar';

  @override
  String get taskFlowUiNameHint => 'Introduzca un nombre de flujo de tareas';

  @override
  String get taskFlowUiDescriptionHint => 'Añade una descripción (opcional)';

  @override
  String get taskFlowUiNameRequired =>
      'Introduzca un nombre de flujo de tareas';

  @override
  String taskFlowUiStepRequired(Object index, Object message) {
    return 'Paso $index: $message';
  }

  @override
  String taskFlowUiParameterRequired(Object block, Object parameter) {
    return 'Se requiere “$parameter” para “$block”';
  }

  @override
  String get taskFlowUiSaveFailed =>
      'No se pudo guardar. Tus cambios todavía están aquí. Intentar otra vez.';

  @override
  String get taskFlowUiRetry => 'Rever';

  @override
  String get taskFlowUiUpdated => 'Flujo de tareas actualizado';

  @override
  String get taskFlowUiCreated => 'Flujo de tareas creado';

  @override
  String get taskFlowUiTitle => 'Flujo de tareas';

  @override
  String get taskFlowUiNotFound => 'Tarea no encontrada';

  @override
  String get taskFlowUiBack => 'Atrás';

  @override
  String get taskFlowUiEdit => 'Editar';

  @override
  String taskFlowUiInput(Object label) {
    return 'Entrada ($label)';
  }

  @override
  String get taskFlowUiInputHint => 'Introduzca texto o un enlace';

  @override
  String get taskFlowUiStart => 'Iniciar flujo de tareas';

  @override
  String get taskFlowUiNoInput =>
      'Aún no hay entradas. Toque a continuación para agregar una URL de recurso web.';

  @override
  String get taskFlowUiAddResource => 'Agregar recurso web';

  @override
  String get taskFlowUiUrlHint =>
      'Ingrese la URL de una página web de video o audio';

  @override
  String get taskFlowUiDeleteInput => 'Eliminar esta entrada';

  @override
  String get taskFlowUiHour => 'hora';

  @override
  String get taskFlowUiMinute => 'mín.';

  @override
  String get taskFlowUiSecond => 'segundo';

  @override
  String get taskFlowUiPreview => 'Avance:';

  @override
  String get taskFlowUiDurationFormat => 'hh:mm:ss';

  @override
  String get taskFlowUiDurationHint =>
      'Opcional: filtre los recursos de vídeo por duración. Déjelo en blanco para mostrar todos los recursos disponibles.';

  @override
  String get taskFlowUiSelectImages => 'Seleccionar imágenes (múltiples)';

  @override
  String get taskFlowUiSelectAudio => 'Seleccionar audio (múltiple)';

  @override
  String get taskFlowUiSelectFiles => 'Seleccionar archivos (múltiples)';

  @override
  String get taskFlowUiSelectVideo => 'Seleccionar videos (múltiples)';

  @override
  String get taskFlowUiRemove => 'Eliminar';

  @override
  String taskFlowUiRemovedFileCleanupFailed(Object error) {
    return 'No se pudo limpiar el archivo eliminado: $error';
  }

  @override
  String get taskFlowUiInitialInput => '0. Entrada inicial';

  @override
  String taskFlowUiInputType(Object type) {
    return 'Tipo de entrada: $type';
  }

  @override
  String get taskFlowUiUserFlowInput =>
      'Entrada proporcionada cuando el usuario ejecuta el flujo de tareas';

  @override
  String taskFlowUiBlockInput(Object type) {
    return 'Entrada: $type';
  }

  @override
  String taskFlowUiBlockOutput(Object type) {
    return 'Salida: $type';
  }

  @override
  String get taskFlowUiParameters => 'Parámetros:';

  @override
  String get taskFlowUiClose => 'Cerrar';

  @override
  String get taskFlowUiSelectAppImages =>
      'Seleccione imágenes de la aplicación (múltiples)';

  @override
  String get taskFlowUiNoImages => 'Sin imágenes';

  @override
  String get taskFlowUiSelectAppAudio =>
      'Seleccione audio de la aplicación (múltiples)';

  @override
  String get taskFlowUiNoAudio => 'Sin audio';

  @override
  String get taskFlowUiSelectAppVideo =>
      'Seleccionar videos de la aplicación (múltiples)';

  @override
  String get taskFlowUiNoVideo => 'Sin vídeos';

  @override
  String taskFlowUiFileSelectFailed(Object error) {
    return 'No se pudo seleccionar el archivo: $error';
  }

  @override
  String taskFlowUiFileTooLarge(Object limit, Object name) {
    return '“$name” supera $limit MB. Elija un archivo más pequeño.';
  }

  @override
  String taskFlowUiFileUnreadable(Object name) {
    return '“$name” está vacío o es ilegible';
  }

  @override
  String get taskFlowUiSomeFilesMissing =>
      'Faltan algunos archivos y se omitieron';

  @override
  String taskFlowUiSelectedFilesUnavailable(int count) {
    return 'No se puede acceder a los archivos seleccionados $count. Seleccione todos los archivos nuevamente.';
  }

  @override
  String get taskFlowUiQueuedOne => 'Flujo de tareas agregado a la cola';

  @override
  String taskFlowUiQueuedMany(Object count) {
    return 'Se agregaron flujos de tareas $count a la cola';
  }

  @override
  String get taskFlowUiRunTitle => 'Esta carrera';

  @override
  String get taskFlowUiCancelBatch => 'Cancelar lote completo';

  @override
  String get taskFlowUiRestoringRecords =>
      'Restaurando registros de flujo de tareas...';

  @override
  String get taskFlowUiRecordsPaused =>
      'No se pudieron cargar los registros de flujo de tareas. Las acciones de las tareas están en pausa.';

  @override
  String get taskFlowUiRecordsCleared =>
      'Se han borrado los registros de esta ejecución.';

  @override
  String taskFlowUiRunsFinished(Object finished, Object total) {
    return 'Ejecuciones $finished de $total finalizadas';
  }

  @override
  String taskFlowUiRecordsRemoved(Object count) {
    return '· Registros $count borrados';
  }

  @override
  String get taskFlowUiTemporaryFiles => 'Archivos intermedios temporales';

  @override
  String get taskFlowUiAddBlock => 'Agregar bloque';

  @override
  String taskFlowUiInsertBlockBefore(Object index) {
    return 'Insertar bloque antes del paso $index';
  }

  @override
  String get taskFlowUiIncompatibleAdjacentBlocks =>
      'Ningún bloque es compatible con ambos escalones adyacentes. Primero ajuste los escalones adyacentes.';

  @override
  String taskFlowUiInsertBeforeStep(Object index) {
    return 'Insertar antes del paso $index';
  }

  @override
  String get taskFlowUiUnknown => 'Desconocido';

  @override
  String get taskFlowUiChooseBlock => 'Elige un bloque';

  @override
  String get taskFlowUiInsertBlock => 'Insertar bloque';

  @override
  String get taskFlowUiPreviousOutput => 'Salida del paso anterior';

  @override
  String taskFlowUiNextStepNeeds(Object label) {
    return '; el siguiente paso necesita: $label';
  }

  @override
  String get taskFlowUiNoCompatibleBlock =>
      'Ningún bloque es compatible con el tipo actual';

  @override
  String get taskFlowUiReplaceBlock => 'Reemplazar bloque';

  @override
  String get taskFlowUiBlockCompatibility =>
      'Solo puedes reemplazarlo con un bloque que tenga tipos de entrada y salida compatibles.';

  @override
  String get taskFlowUiTemporaryCleanupTooltip =>
      'La limpieza después del siguiente paso guarda el resultado correctamente; El paso final siempre se mantiene.';

  @override
  String get taskFlowUiSetParameters => 'Establecer parámetros';

  @override
  String get taskFlowUiReplace => 'Reemplazar';

  @override
  String get taskFlowUiViewParameters => 'Toque para ver los parámetros';

  @override
  String get taskFlowUiTapSetParameters =>
      'Toque para configurar los parámetros';

  @override
  String taskFlowUiUnknownBlockType(Object name) {
    return 'Bloque desconocido: $name';
  }

  @override
  String get taskFlowUiBlockUnregistered =>
      'Este tipo de bloque no está registrado';

  @override
  String taskFlowUiStepActions(Object index) {
    return 'Acciones para el paso $index';
  }

  @override
  String get taskFlowUiInsertBefore => 'Insertar antes';

  @override
  String get taskFlowUiInsertAfter => 'Insertar después';

  @override
  String get taskFlowUiCopyBlock => 'Bloque duplicado';

  @override
  String get taskFlowUiMoveUp => 'Subir';

  @override
  String get taskFlowUiMoveUpDisabled => 'Subir (ya es el primero)';

  @override
  String get taskFlowUiMoveDown => 'Bajar';

  @override
  String get taskFlowUiMoveDownDisabled =>
      'Mover hacia abajo (ya es el último)';

  @override
  String get taskFlowUiDeleteBlock => 'Eliminar bloque';

  @override
  String taskFlowUiInputLabel(Object label) {
    return 'Entrada: $label';
  }

  @override
  String taskFlowUiOutputLabel(Object label) {
    return 'Salida: $label';
  }

  @override
  String taskFlowUiUnregisteredBlockType(Object name) {
    return 'El tipo de bloque “$name” no está registrado';
  }

  @override
  String taskFlowUiBlockSettings(Object label) {
    return 'Configuración de $label';
  }

  @override
  String get taskFlowUiSendToAssistant =>
      'El mensaje de usuario enviado al asistente es el resultado del paso anterior.';

  @override
  String get taskFlowUiTempSpaceInfo =>
      'Este paso sale al espacio temporal del flujo. Su salida se limpia después de que el siguiente paso se guarde correctamente. La carpeta de guardado original se conserva y restaura cuando el modo temporal está desactivado.';

  @override
  String get taskFlowUiNoExtraParameters =>
      'Este bloque no tiene parámetros adicionales';

  @override
  String get taskFlowUiCancel => 'Cancelar';

  @override
  String get taskFlowUiConfirm => 'Confirmar';

  @override
  String get taskFlowUiConfigureModelFirst => 'Configurar un modelo primero';

  @override
  String get taskFlowUiModelUnavailable =>
      'No se ha seleccionado ningún modelo o el modelo no está disponible. Seleccione otro modelo.';

  @override
  String taskFlowUiModelIndexed(Object index) {
    return 'Modelo $index';
  }

  @override
  String get taskFlowUiUnnamedProvider => 'Proveedor sin nombre';

  @override
  String get taskFlowUiCustomModelParameters =>
      'Parámetros del modelo personalizado';

  @override
  String get taskFlowUiTtsVoiceMissing =>
      'Ningún modelo TTS tiene voces configuradas. Puede ingresar una identificación manualmente.';

  @override
  String get taskFlowUiVoiceUnavailable =>
      'La voz no está disponible. Seleccione otra voz.';

  @override
  String get taskFlowUiSelectVoice => 'Seleccione una voz';

  @override
  String get taskFlowUiAssistantUnavailable => 'Asistente no disponible';

  @override
  String get taskFlowUiAssistantUseCurrent =>
      'No especificado (use el asistente seleccionado actualmente)';

  @override
  String get taskFlowUiAssistantDeleted =>
      'El asistente configurado fue eliminado. Seleccione otro asistente.';

  @override
  String get taskFlowUiChooseAssistant => 'Elige un asistente';

  @override
  String get taskFlowUiOnlyCustomAssistants =>
      'Solo se puede seleccionar “Mis asistentes” (agregue uno en “Chat → Asistentes”)';

  @override
  String get taskFlowUiMyAssistants => 'Mis asistentes';

  @override
  String get taskFlowUiNoCustomAssistants =>
      'Aún no hay asistentes personalizados. Crea uno en “Chat → Asistentes”.';

  @override
  String get taskFlowUiYes => 'Sí';

  @override
  String get taskFlowUiNo => 'No';

  @override
  String get taskFlowUiDefaultRoot => 'Predeterminado (carpeta raíz)';

  @override
  String get taskFlowUiSelect => 'Seleccionar';

  @override
  String get taskFlowUiSelectSaveFolder => 'Elija una carpeta para guardar';

  @override
  String get taskFlowUiCatCatchVideo => 'Video';

  @override
  String get taskFlowUiCatCatchAudio => 'Audio';

  @override
  String get taskFlowUiCatCatchEither =>
      'Vídeo o audio (filtro basado en pasos posteriores)';

  @override
  String get taskFlowUiManual => 'Manual';

  @override
  String get taskFlowUiAutomatic => 'Automático';

  @override
  String get taskFlowUiAutomaticPrompt => 'Automático con confirmación';

  @override
  String get taskFlowUiEditTitle => 'Editar flujo de tareas';

  @override
  String get taskFlowUiCreateTitle => 'Nuevo flujo de tareas';

  @override
  String taskFlowUiStepNumber(Object index, Object message) {
    return 'Paso $index: $message';
  }

  @override
  String taskFlowUiInputTypeValue(Object type) {
    return 'Tipo de entrada: $type';
  }

  @override
  String taskFlowUiBlockInputValue(Object type) {
    return 'Entrada: $type';
  }

  @override
  String taskFlowUiBlockOutputValue(Object type) {
    return 'Salida: $type';
  }

  @override
  String taskFlowUiCleanupError(Object error) {
    return 'No se pudo limpiar el archivo eliminado: $error';
  }

  @override
  String taskFlowUiSelectFileError(Object error) {
    return 'No se pudo seleccionar el archivo: $error';
  }

  @override
  String taskFlowUiLargeFile(Object limit, Object name) {
    return '“$name” supera $limit MB. Elija un archivo más pequeño.';
  }

  @override
  String taskFlowUiUnreadableFile(Object name) {
    return '“$name” está vacío o es ilegible';
  }

  @override
  String get taskFlowUiTemporary => 'Temporario';

  @override
  String get taskFlowUiTemporaryFileHint =>
      'Archivo temporal (limpiado después de que el siguiente paso sea exitoso)';

  @override
  String taskFlowUiUnregisteredBlock(Object name) {
    return 'El tipo de bloque “$name” no está registrado';
  }

  @override
  String taskFlowUiRunSummary(Object finished, Object total) {
    return 'Ejecuciones $finished de $total finalizadas';
  }

  @override
  String taskFlowUiClearedRecordCount(Object count) {
    return '· Registros $count borrados';
  }

  @override
  String taskFlowUiInputOutput(Object input, Object output) {
    return 'Entrada: $input → Salida: $output';
  }

  @override
  String get taskFlowCardTag => 'Flujo de tareas';

  @override
  String get taskFlowCardQueued => 'En cola (esperando recursos)';

  @override
  String taskFlowCardCompletedProgress(Object done, Object total) {
    return '$done de $total completado';
  }

  @override
  String taskFlowCardCountLabel(Object count, Object label) {
    return '$count $label';
  }

  @override
  String get taskFlowCardFailedLabel => 'fallido';

  @override
  String get taskFlowCardSkippedLabel => 'saltado';

  @override
  String get taskFlowCardCancelledLabel => 'cancelado';

  @override
  String get taskFlowCardInterruptedLabel => 'interrumpido';

  @override
  String get taskFlowCardCancelFlow => 'Cancelar flujo';

  @override
  String get taskFlowCardRetry => 'Rever';

  @override
  String get taskFlowCardCancelBatch => 'Cancelar lote completo';

  @override
  String get taskFlowCardDelete => 'Borrar';

  @override
  String get taskFlowCardRetryFlow => 'Reintentar el flujo de tareas';

  @override
  String get taskFlowCardNoSnapshot =>
      'Esta ejecución no tiene instantánea. Comenzará de nuevo utilizando la configuración de flujo actual.';

  @override
  String get taskFlowCardRetryInfo =>
      'Comenzar de nuevo descarga archivos y llama a los modelos nuevamente. Vuelva a intentarlo con la configuración utilizada en el inicio o elija explícitamente la configuración más reciente. Para reutilizar los pasos completados, elija \"Reanudar desde el paso interrumpido\".';

  @override
  String get taskFlowCardRunLatest => 'Ejecutar con la última configuración';

  @override
  String get taskFlowCardRetryOriginal =>
      'Reintentar con la configuración original';

  @override
  String get taskFlowCardDeleteRecord => 'Eliminar registro de flujo de tareas';

  @override
  String get taskFlowCardDeleteBatchConfirm =>
      'Eliminar esta ejecución cancelará las tareas inacabadas en el lote y borrará sus registros de subtareas. ¿Borrar?';

  @override
  String get taskFlowCardDeleteRunningConfirm =>
      'Este flujo está funcionando. Eliminarlo cancelará sus tareas activas. ¿Borrar?';

  @override
  String get taskFlowCardDeleteRecordConfirm =>
      '¿Eliminar este registro de flujo y sus registros de subtarea?';

  @override
  String get taskFlowCardDeleteConfirm => '¿Eliminar este registro de flujo?';

  @override
  String get taskFlowCardSaveCancelStateError =>
      'No se pudo guardar el estado de cancelación del flujo. Intente eliminar nuevamente.';

  @override
  String get taskFlowCardStillRunning =>
      'El flujo sigue funcionando después de la cancelación.';

  @override
  String get taskFlowCardSaveDeleteStateError =>
      'No se pudo guardar el estado de eliminación del registro de flujo. Intente eliminar nuevamente.';

  @override
  String get taskFlowCardConfirm => 'Confirmar';

  @override
  String get taskFlowCardWaiting => 'Espera';

  @override
  String get taskFlowCardRunning => 'Correr';

  @override
  String get taskFlowCardPaused => 'En pausa';

  @override
  String get taskFlowCardCompleted => 'Terminado';

  @override
  String get taskFlowCardFailed => 'Fallido';

  @override
  String get taskFlowCardCanceled => 'Cancelado';

  @override
  String get taskFlowCardInterrupted => 'interrumpido';

  @override
  String get taskFlowCardSucceeded => 'Saltado';

  @override
  String get taskFlowCardPause => 'Pausar el flujo';

  @override
  String get taskFlowCardResume => 'Reanudar flujo';

  @override
  String get taskFlowCardResumeInterrupted =>
      'Reanudar desde el paso interrumpido';

  @override
  String get taskFlowCardCancel => 'Cancelar';

  @override
  String get unifiedTaskType => 'Tipo de tarea';

  @override
  String get unifiedTaskCreatedAt => 'Creado';

  @override
  String get unifiedTaskCompletedAt => 'Terminado';

  @override
  String get unifiedTaskResultStatus => 'Estado del resultado';

  @override
  String get unifiedTaskPartialResult =>
      'Resultado parcial; el contenido puede estar incompleto';

  @override
  String get unifiedTaskErrorDetails => 'Detalles del error';

  @override
  String get unifiedTaskViewErrorDetails => 'Ver detalles del error';

  @override
  String get unifiedTaskOcrPerImage => 'Reconocer cada imagen';

  @override
  String unifiedTaskOcrPageIndex(Object index) {
    return 'Imagen $index';
  }

  @override
  String get unifiedTaskOcrPending => 'esperando reconocer';

  @override
  String get unifiedTaskOcrRunning => 'Reconociendo';

  @override
  String get unifiedTaskCompleted => 'Terminado';

  @override
  String get unifiedTaskIncomplete => 'resultado incompleto';

  @override
  String get unifiedTaskOcrFailed => 'El reconocimiento falló';

  @override
  String get unifiedTaskCancelled => 'Cancelado';

  @override
  String get unifiedTaskWaitingStart => 'Esperando empezar...';

  @override
  String get unifiedTaskSteps => 'Pasos';

  @override
  String get unifiedTaskStartNow => 'Empezar ahora';

  @override
  String get unifiedTaskOpenFile => 'Abrir archivo';

  @override
  String get unifiedTaskRetrySave => 'Reintentar guardar solo';

  @override
  String get unifiedTaskRetryPartialSave =>
      'Reintentar guardar solo el resultado parcial';

  @override
  String get unifiedTaskSavePartialResult => 'Guardar resultado parcial';

  @override
  String get unifiedTaskRetry => 'Rever';

  @override
  String get unifiedTaskCancel => 'Cancelar';

  @override
  String get unifiedTaskDelete => 'Borrar';

  @override
  String get unifiedTaskFormatUnsupported =>
      'La vista previa no es compatible con este formato';

  @override
  String unifiedTaskLoadFailed(Object error) {
    return 'Error de carga: $error';
  }

  @override
  String unifiedTaskPlaybackFailed(Object error) {
    return 'Error de reproducción: $error';
  }

  @override
  String get unifiedTaskAudioFile => 'archivo de audio';

  @override
  String get unifiedTaskPreviewLoadFailed =>
      'No se pudo cargar la vista previa';

  @override
  String get unifiedTaskUnknownSize => 'Tamaño desconocido';

  @override
  String get unifiedTaskUnnamedRecording => 'Grabación sin título';

  @override
  String get unifiedTaskPause => 'Pausa';

  @override
  String get unifiedTaskClearTask => 'Borrar tarea';

  @override
  String get unifiedTaskContinue => 'Continuar';

  @override
  String get unifiedTaskRemoveFromList => 'Eliminar de la lista';

  @override
  String get unifiedTaskSynthesisText => 'Texto sintetizado';

  @override
  String get unifiedTaskStatus => 'Estado';

  @override
  String get unifiedTaskDetails => 'Detalles';

  @override
  String get unifiedTaskSynthesisError => 'Detalles del error de síntesis';

  @override
  String get unifiedTaskClose => 'Cerrar';

  @override
  String get unifiedTaskRawRequestResponse =>
      'Solicitud y respuesta sin procesar';

  @override
  String get unifiedTaskRawRequestBody => 'Cuerpo de solicitud sin formato:';

  @override
  String get unifiedTaskRawResponseBody => 'Cuerpo de respuesta sin procesar:';

  @override
  String get commonJustNow => 'En este momento';

  @override
  String commonMinutesAgo(Object count) {
    return '$count hace minutos';
  }

  @override
  String commonHoursAgo(Object count) {
    return '$count hace horas';
  }

  @override
  String unifiedDurationSeconds(Object seconds) {
    return '$seconds seg.';
  }

  @override
  String unifiedDurationMinutesSeconds(Object minutes, Object seconds) {
    return '$minutes min $seconds seg';
  }

  @override
  String unifiedDurationHoursMinutes(Object hours, Object minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get unifiedTaskTypeOcr => 'Reconocimiento de texto de imagen';

  @override
  String get unifiedTaskTypeAsr => 'Transcripción de audio';

  @override
  String get unifiedTaskTypeAudioSeparation => 'Separación de audio';

  @override
  String backgroundTaskGeneratedOcrTitle(Object basename) {
    return 'OCR: $basename';
  }

  @override
  String backgroundTaskGeneratedAudioSeparationTitle(Object basename) {
    return 'Separación de audio: $basename';
  }

  @override
  String get unifiedTaskTypeChat => 'Chat asistente';

  @override
  String get unifiedTaskPlayAudio => 'Reproducir audio';

  @override
  String get unifiedTaskPauseAudio => 'Pausar audio';

  @override
  String get catcatchFlowActionNotStarted =>
      'La acción de flujo no comenzó. Verifique el estado del flujo e inténtelo nuevamente.';

  @override
  String catcatchFlowActionFailed(Object error) {
    return 'Error en la acción de flujo: $error';
  }

  @override
  String get catcatchWebViewRecoveryGuidance =>
      'Se agotó el tiempo de espera para el escaneo automático de páginas. Inicie sesión o configure un script de usuario en esta página; Después de que se detecte el medio, elija Continuar flujo.';

  @override
  String get browserRecoveryContinue => 'Continuar flujo';

  @override
  String get catcatchSkipped => 'Omitido (nada que procesar)';

  @override
  String catCatchDetailMediaResources(Object count) {
    return 'Se encontraron recursos multimedia $count';
  }

  @override
  String catCatchDetailResources(Object count) {
    return 'Recursos $count encontrados';
  }

  @override
  String catCatchDetailBrowserResources(Object count) {
    return 'El navegador encontró recursos $count';
  }

  @override
  String catCatchDetailPlaylistResources(Object total, Object segments) {
    return 'Recursos $total encontrados (segmentos de lista de reproducción $segments)';
  }

  @override
  String catCatchDetailChooseResource(Object count) {
    return 'Se encontraron recursos $count. Elige uno.';
  }

  @override
  String get catCatchDetailAutoSelectFirst =>
      'Se seleccionó automáticamente el resultado 1 y se inició la descarga.';

  @override
  String get catCatchDetailAutoSelectRemaining =>
      'Queda 1 resultado; comenzó a descargarse automáticamente';

  @override
  String catCatchDetailSkipFormat(Object extension) {
    return 'Se omitió la conversión para .$extension; este formato no necesita conversión';
  }

  @override
  String get catCatchDetailSkipNoExtension =>
      'Se omitió la conversión; este formato no necesita conversión';

  @override
  String catCatchDetailDurationFiltered(
    Object duration,
    Object remaining,
    Object removed,
  ) {
    return 'Después de filtrar $duration, los resultados de $remaining permanecen (se excluyen los recursos no coincidentes de $removed)';
  }

  @override
  String catCatchDetailDurationAllMatch(Object count, Object duration) {
    return 'Todos los recursos $count coinciden con el filtro de duración $duration';
  }

  @override
  String catCatchDurationHours(Object count) {
    return '${count}h';
  }

  @override
  String catCatchDurationMinutes(Object count) {
    return '${count}m';
  }

  @override
  String catCatchDurationSeconds(Object count) {
    return '$count';
  }

  @override
  String get catcatchRetryStep => 'Vuelva a intentar este paso';

  @override
  String catcatchCollapseSegments(Object count) {
    return 'Ocultar segmentos $count';
  }

  @override
  String catcatchShowSegments(Object count) {
    return 'Mostrar segmentos $count';
  }

  @override
  String catcatchSelectedResources(Object selected, Object total) {
    return '$selected de recursos $total seleccionados';
  }

  @override
  String catcatchDetectedMediaResources(Object count) {
    return '$count recursos multimedia detectados';
  }

  @override
  String get catcatchFlowSelectOrCombine =>
      '(seleccione un recurso o combine un par de audio/vídeo)';

  @override
  String get catcatchSelectMultiple =>
      '(toque para seleccionar; se permiten múltiples)';

  @override
  String get catcatchWaitingForResources => 'Esperando recursos de flujo';

  @override
  String catcatchDownloadSelected(Object count) {
    return 'Descargar recursos seleccionados $count';
  }

  @override
  String get catcatchSelectResources => 'Seleccionar recursos para descargar';

  @override
  String get catcatchPossibleSplit =>
      '⚠ Posibles transmisiones de audio y video separadas';

  @override
  String get catcatchSplitExplanation =>
      'Estos recursos pueden ser transmisiones de audio y video separadas para el mismo video. Puedes combinarlos o descargar solo una transmisión.';

  @override
  String get catcatchAudioStream => '🎵 Transmisión de audio';

  @override
  String get catcatchVideoStream => '🎬 Transmisión de vídeo';

  @override
  String get catcatchMergeAudioVideo => 'Combina audio y vídeo';

  @override
  String get catcatchVideoOnly => 'Sólo vídeo';

  @override
  String get catcatchAudioOnly => 'Sólo audio';

  @override
  String get catcatchSegmentsPlaylistPreview =>
      'Vista previa de segmentos usando la lista de reproducción';

  @override
  String get catcatchPreviewAudio => 'Vista previa de audio';

  @override
  String get catcatchPreviewVideo => 'Vista previa de vídeo';

  @override
  String catcatchDuration(Object duration) {
    return 'Duración: $duration';
  }

  @override
  String get catcatchSegment => 'Segmento';

  @override
  String get catcatchPlaylist => 'Lista de reproducción';

  @override
  String get catcatchFullVideo => 'vídeo completo';

  @override
  String get catcatchSeparateTracks => 'Pistas separadas';

  @override
  String get catcatchPreviewPlaylistOnly =>
      'Vista previa usando la lista de reproducción';

  @override
  String get catcatchPreviewUnsupported => 'La vista previa no es compatible';

  @override
  String get catcatchUnknownFormat => 'Formato desconocido';

  @override
  String get catcatchNeedPlaylistProcessing =>
      'Se requiere procesamiento de lista de reproducción';

  @override
  String get catcatchSpecialFormatDetected => 'Formato especial detectado';

  @override
  String catcatchPlaylistInfo(Object format) {
    return 'Este recurso es una lista de reproducción ($format). Debe analizarse y descargarse todos los segmentos y combinarse en un vídeo reproducible.';
  }

  @override
  String catcatchFormatInfo(Object format) {
    return 'El archivo descargado está en $format, no en MP4 estándar. El motor Dart remux incorporado puro lo convertirá a MP4 (TS/FLV/EV1 no requiere dependencias externas).';
  }

  @override
  String get catcatchContinueBeforeConfirm =>
      'Reanudar el flujo antes de confirmar el manejo del formato.';

  @override
  String get catcatchAutoProcess => 'Procesar automáticamente';

  @override
  String get catcatchKeepOriginalFormat => 'Mantener formato original';

  @override
  String get catcatchResumeSupported => 'Reanudar apoyado';

  @override
  String get catcatchResumeUnsupported =>
      'Este sitio no admite la reanudación.';

  @override
  String get catcatchPauseDownload => 'Pausar descarga';

  @override
  String get catcatchResumeDownload => 'Reanudar descarga';

  @override
  String get catcatchRestartDownload => 'Descargar de nuevo';

  @override
  String get catcatchPendingFormatAction => 'Esperando recursos de flujo';

  @override
  String get quitDialogTitle => '¿Salir de la aplicación?';

  @override
  String quitDialogRunningTasks(Object count) {
    return 'Las tareas $count se están ejecutando. Dejar de fumar los interrumpirá. ¿Quieres dejarlo?';
  }

  @override
  String get quitDialogNoTasks => '¿Quieres dejar Stroom?';

  @override
  String get quitDialogCancel => 'Cancelar';

  @override
  String get quitDialogExit => 'Abandonar';

  @override
  String get searchPanelNewConversation => 'Nueva conversación';

  @override
  String get searchPanelTitle => 'Buscar conversaciones';

  @override
  String get searchPanelHint => 'Introduzca una palabra clave...';

  @override
  String get searchPanelByTitle => 'Buscar títulos';

  @override
  String get searchPanelByContent => 'Buscar contenido';

  @override
  String searchPanelResults(Object count) {
    return '$count resultados';
  }

  @override
  String get searchPanelPrompt => 'Ingrese una palabra clave para buscar';

  @override
  String get searchPanelNoResults =>
      'No se encontraron conversaciones coincidentes';

  @override
  String get topicItemNew => 'Nuevo tema';

  @override
  String get topicItemUnpin => 'Desprender';

  @override
  String get topicItemPin => 'Alfiler';

  @override
  String get topicItemRename => 'Rebautizar';

  @override
  String get topicItemAutoName => 'Nombre automático';

  @override
  String get topicItemDelete => 'Borrar';

  @override
  String get galleryChoiceTitle => 'Elige una fuente de imagen';

  @override
  String get galleryChoiceDevice => 'Galería de dispositivos';

  @override
  String get galleryChoiceDeviceDescription =>
      'Explora fotos y vídeos en tu dispositivo';

  @override
  String get galleryChoiceApp => 'galería de aplicaciones';

  @override
  String get galleryChoiceAppDescription =>
      'Elige de la galería de aplicaciones';

  @override
  String get appMediaUnreadable => 'No se pudo leer el archivo';

  @override
  String appMediaLoadError(Object error) {
    return 'No se pudieron cargar archivos: $error';
  }

  @override
  String appMediaClearSelection(Object count) {
    return 'Borrar ($count)';
  }

  @override
  String appMediaConfirmSelectionCount(Object count) {
    return 'Hecho ($count)';
  }

  @override
  String get appMediaConfirmSelection => 'Hecho';

  @override
  String get appMediaEmptyFolder => 'Esta carpeta está vacía';

  @override
  String get appMediaRoot => 'Ir a la carpeta raíz';

  @override
  String appMediaParentFolder(Object name) {
    return 'Atrás: $name';
  }

  @override
  String appMediaSelectedFiles(Object count) {
    return 'Archivos $count seleccionados';
  }

  @override
  String get chatAlbumPickerTitle => 'Álbum de aplicaciones';

  @override
  String get chatAlbumPickerEmpty => 'No hay imágenes disponibles';

  @override
  String appAlbumPickerSelectedImages(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imágenes seleccionadas',
      one: '$count imagen seleccionada',
    );
    return '$_temp0';
  }

  @override
  String get chatFilePickerTitle => 'Elige archivos';

  @override
  String get chatFilePickerTabText => 'Texto';

  @override
  String get chatFilePickerTabImages => 'Imágenes';

  @override
  String get chatFilePickerTabVideos => 'Vídeos';

  @override
  String get chatFilePickerTabAudio => 'Audio';

  @override
  String get chatFilePickerEmpty => 'No hay archivos disponibles';

  @override
  String get chatFilePickerLoadFailed => 'No se pudieron cargar archivos';

  @override
  String get chatVideoPickerTitle => 'Elige vídeos de la aplicación';

  @override
  String get chatVideoPickerEmpty => 'No hay vídeos disponibles';

  @override
  String get imagePreviewCrop => 'Cultivo';

  @override
  String get imagePreviewEdit => 'Editar';

  @override
  String get imagePreviewLoadFailed => 'No se pudo cargar la imagen';

  @override
  String runningElapsed(Object elapsed) {
    return 'Corriendo para $elapsed';
  }

  @override
  String get chatAttachmentFile => 'Adjuntar archivo';

  @override
  String get chatAttachmentCamera => 'tomar foto';

  @override
  String get chatAttachmentDeviceGallery => 'Galería de dispositivos';

  @override
  String get chatAttachmentDeviceFiles => 'Archivos de dispositivo';

  @override
  String get chatAttachmentAppFiles => 'Archivos de aplicación';

  @override
  String fileManagerTodayTime(Object time) {
    return 'Hoy $time';
  }

  @override
  String fileManagerYesterdayTime(Object time) {
    return 'Ayer $time';
  }

  @override
  String fileManagerDaysAgoTime(Object days, Object time) {
    return 'Hace $days días $time';
  }

  @override
  String get markdownGenerating => 'Generando...';

  @override
  String get htmlPreview => 'Avance';

  @override
  String get htmlReturnToCard => 'volver a la tarjeta';

  @override
  String get htmlGenerating => 'Generando...';

  @override
  String get htmlFullscreen => 'Ver pantalla completa';

  @override
  String get htmlViewCode => 'Ver código';

  @override
  String get codeScrollToBottom => 'Desplazarse hacia abajo';

  @override
  String get codeSave => 'Guardar';

  @override
  String get codeDisableWrap => 'Desactivar envoltura';

  @override
  String get codeEnableWrap => 'Líneas envolventes';

  @override
  String codeCopyFailed(Object error) {
    return 'Copia fallida: $error';
  }

  @override
  String get codeCopied => 'Copiado';

  @override
  String get codeCopy => 'Copiar';

  @override
  String get codeEmptySave => 'El código está vacío y no se puede guardar.';

  @override
  String get codeSaveTitle => 'Guardar código';

  @override
  String codeSavedTo(Object path) {
    return 'Guardado en: $path';
  }

  @override
  String codeSaveFailed(Object error) {
    return 'Error al guardar: $error';
  }

  @override
  String get fileManagerCopy => 'Copiar';

  @override
  String get fileManagerMove => 'Mover';

  @override
  String get fileManagerRename => 'Rebautizar';

  @override
  String get fileManagerExport => 'Exportar';

  @override
  String get fileManagerDelete => 'Borrar';

  @override
  String get fileManagerAncestorFolders => 'Carpetas de antepasados';

  @override
  String get fileManagerRoot => 'Raíz';

  @override
  String fileManagerSelectedItems(Object count) {
    return '$count seleccionado';
  }

  @override
  String get fileManagerSelectAll => 'Seleccionar todo';

  @override
  String get fileManagerRenameUndo =>
      'Resultado de cambio de nombre del último lote y deshacer';

  @override
  String fileManagerSortBy(Object field) {
    return 'Ordenar ($field)';
  }

  @override
  String get fileManagerSortCreated => 'Ordenar por fecha de creación';

  @override
  String get fileManagerSortModified => 'Ordenar por fecha de modificación';

  @override
  String get fileManagerSortName => 'Ordenar por nombre';

  @override
  String get fileManagerSortSize => 'Ordenar por tamaño';

  @override
  String get fileManagerListView => 'Vista de lista';

  @override
  String get fileManagerThumbnailView => 'Vista en miniatura';

  @override
  String get fileManagerCreateFolder => 'Crear carpeta';

  @override
  String get fileManagerRefresh => 'Actualizar lista';

  @override
  String get fileManagerEmptyFolder => 'Esta carpeta está vacía';

  @override
  String get fileManagerNoFiles => 'Sin archivos';

  @override
  String get fileManagerBackRoot => 'Volver a la raíz';

  @override
  String fileManagerBackFolder(Object name) {
    return 'Atrás: $name';
  }

  @override
  String get fileManagerMultiSelect => 'Seleccionar múltiples';

  @override
  String get fileManagerOpen => 'Abierto';

  @override
  String get fileManagerPreview => 'Avance';

  @override
  String fileManagerFolderAndFilesCount(Object files, Object folders) {
    return 'Archivos $files, subcarpetas $folders';
  }

  @override
  String fileManagerSubfoldersCount(Object count) {
    return 'Subcarpetas $count';
  }

  @override
  String fileManagerFilesCount(Object count) {
    return 'Archivos $count';
  }

  @override
  String get fileManagerEmptyFolderLabel => 'carpeta vacia';

  @override
  String fileManagerFileExists(Object format, Object name) {
    return 'El archivo “$name.$format” ya existe';
  }

  @override
  String fileManagerRenameFailed(Object error) {
    return 'Error al cambiar el nombre: $error';
  }

  @override
  String get fileManagerChooseTargetFolder => 'Elija una carpeta de destino';

  @override
  String get fileManagerAlreadyAtDestination =>
      'El archivo ya está en el destino.';

  @override
  String get fileManagerMoveNameConflict =>
      'Ya existe un archivo con el mismo nombre en el destino. Movimiento cancelado.';

  @override
  String fileManagerMoveFailed(Object error) {
    return 'Error al mover: $error';
  }

  @override
  String get fileManagerChooseCopyDestination =>
      'Elija una carpeta para copiar';

  @override
  String fileManagerCopyFailed(Object error) {
    return 'Copia fallida: $error';
  }

  @override
  String get fileManagerDeleteConfirmTitle => 'Confirmar eliminación';

  @override
  String get fileManagerDeleteFileConfirm =>
      '¿Eliminar este archivo? Esta acción no se puede deshacer.';

  @override
  String get fileManagerCancel => 'Cancelar';

  @override
  String fileManagerDeleteFailed(Object error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get fileManagerFolderAlreadyThere =>
      'La carpeta ya está en el destino. Operación cancelada.';

  @override
  String get fileManagerFolderConflict =>
      'Existe una carpeta con el mismo nombre en el destino o el destino está dentro de la carpeta seleccionada. Operación cancelada.';

  @override
  String get fileManagerBatchDeleteTitle => 'Confirmar eliminación masiva';

  @override
  String fileManagerDeleteSelectedConfirm(Object count) {
    return '¿Eliminar los elementos seleccionados $count? Esta acción no se puede deshacer.';
  }

  @override
  String fileManagerBatchDeleteFailed(Object error) {
    return 'Error en la eliminación masiva: $error';
  }

  @override
  String get fileManagerExportConflict =>
      'Las rutas de exportación para los archivos y carpetas seleccionados entran en conflicto';

  @override
  String get fileManagerSelectedAlreadyThere =>
      'El archivo seleccionado ya está en el destino. Movimiento cancelado.';

  @override
  String fileManagerBatchMoveFailed(Object error) {
    return 'Error en el movimiento masivo: $error';
  }

  @override
  String get fileManagerCopyConflict =>
      'La selección contiene archivos con nombres duplicados. Copia cancelada; cópielos uno a la vez.';

  @override
  String fileManagerBatchCopyFailed(Object error) {
    return 'Error en la copia masiva: $error';
  }

  @override
  String get fileManagerClosedError => 'La página del archivo está cerrada.';

  @override
  String fileManagerBatchRenameFailed(Object error) {
    return 'Error al cambiar el nombre en masa: $error';
  }

  @override
  String get fileManagerFolderNameHint => 'Introduzca un nombre de carpeta';

  @override
  String get fileManagerCreate => 'Crear';

  @override
  String get fileManagerFolderExists => 'La carpeta ya existe';

  @override
  String fileManagerCreateFolderFailed(Object error) {
    return 'No se pudo crear la carpeta: $error';
  }

  @override
  String fileManagerFolderCreated(Object name) {
    return 'Carpeta “$name” creada';
  }

  @override
  String get fileManagerRenameFolderTitle => 'Cambiar nombre de carpeta';

  @override
  String get fileManagerNewNameHint => 'Introduzca un nuevo nombre';

  @override
  String get fileManagerTargetFolderConflict =>
      'Ya existe una carpeta con el mismo nombre en el destino. Operación cancelada.';

  @override
  String get fileManagerMoveFolderTitle => 'Mover carpeta a…';

  @override
  String get fileManagerCopyFolderTitle => 'Copiar carpeta a…';

  @override
  String get fileManagerFolderSelfConflict =>
      'Existe una carpeta con el mismo nombre en el destino o el destino es la carpeta misma. Operación cancelada.';

  @override
  String fileManagerDeleteFolderConfirm(Object count, Object name) {
    return '¿Eliminar la carpeta “$name”? También se eliminarán sus archivos $count.';
  }

  @override
  String fileManagerDeleteEmptyFolderConfirm(Object name) {
    return '¿Eliminar la carpeta vacía “$name”?';
  }

  @override
  String get fileManagerDeleteFolderTitle => 'Confirmar eliminación de carpeta';

  @override
  String fileManagerRefreshFailed(Object error) {
    return 'Error al actualizar: $error';
  }

  @override
  String get fileManagerRefreshed => 'Lista de archivos actualizada';

  @override
  String get fileManagerRenameFileTitle => 'Cambiar nombre de archivo';

  @override
  String get fileManagerFormat => 'Formato';

  @override
  String get fileManagerFolderAtDestination =>
      'La carpeta ya está en el destino.';

  @override
  String get folderPickerTitle => 'Elige carpeta';

  @override
  String get folderPickerExists => 'La carpeta ya existe';

  @override
  String folderPickerCreateFailed(Object error) {
    return 'No se pudo crear la carpeta: $error';
  }

  @override
  String folderPickerRefreshFailed(Object error) {
    return 'No se pudo actualizar la lista de carpetas: $error';
  }

  @override
  String get folderPickerInstruction =>
      'Haga clic para seleccionar; haga doble clic para abrir una carpeta';

  @override
  String get folderPickerFileName => 'Nombre del archivo';

  @override
  String get folderPickerFileNameHint => 'Introduzca un nombre de archivo';

  @override
  String get folderPickerBack => 'Sube un nivel';

  @override
  String folderPickerPath(Object path) {
    return 'Raíz > $path';
  }

  @override
  String get folderPickerRoot => 'Raíz';

  @override
  String get folderPickerCurrentFolder => 'Carpeta actual';

  @override
  String get folderPickerSubfolders => 'Subcarpetas';

  @override
  String get folderPickerExistingFolders => 'Carpetas existentes';

  @override
  String get folderPickerCreateNew => 'Crear nueva carpeta';

  @override
  String get folderPickerFolderNameHint => 'Introduzca un nombre de carpeta';

  @override
  String get folderPickerCancelCreate => 'Cancelar creación';

  @override
  String get folderPickerCancel => 'Cancelar';

  @override
  String get folderPickerConfirm => 'Hecho';

  @override
  String batchRunReadFailed(Object error) {
    return 'No se pudo leer la lista de archivos: $error';
  }

  @override
  String get batchRunPreparing => 'Preparante…';

  @override
  String get batchRunUndo => 'Deshacer';

  @override
  String get batchRunRename => 'Rebautizar';

  @override
  String batchRunFailedAction(Object label) {
    return 'No se pudo $label';
  }

  @override
  String batchRunCompletedCount(Object count, Object label) {
    return '$label $count artículos';
  }

  @override
  String batchRunSummary(
    Object completed,
    Object failed,
    Object label,
    Object remaining,
  ) {
    return '$label: $completed tuvo éxito, $failed falló, $remaining restante';
  }

  @override
  String batchRunFailedItem(Object id, Object name) {
    return 'Error: $id → $name';
  }

  @override
  String get batchRunReportCopied => 'Informe de ejecución copiado';

  @override
  String get batchRunCopyFailed => 'La copia falló. Intentar otra vez.';

  @override
  String batchRunWorking(Object label) {
    return '$label…';
  }

  @override
  String get batchRunTitle => 'Resultados de cambio de nombre por lotes';

  @override
  String get batchRunStoppedRetain =>
      'Al detenerse se mantienen los elementos completados. Puede deshacerlos en la página de resultados.';

  @override
  String get batchRunFailedRemaining =>
      'Fallido; Los elementos restantes no fueron procesados.';

  @override
  String get batchRunUndoInfo =>
      'Deshacer restaura los nombres originales de los elementos completados en esta ejecución. Se rechaza deshacer si la lista de archivos ha cambiado desde entonces.';

  @override
  String get batchRunUncertain =>
      'Algunos estados de los artículos no se pudieron confirmar. Verifique la lista de archivos; La función de deshacer automáticamente no está disponible para evitar sobrescribir archivos.';

  @override
  String get batchRunUndoing => 'Restaurando nombres originales...';

  @override
  String get batchRunStopping => 'Parada…';

  @override
  String get batchRunStopRemaining => 'Detener los elementos restantes';

  @override
  String get batchRunCopyReport => 'Copiar informe';

  @override
  String batchRunUndoRemaining(Object count) {
    return 'Continúe deshaciendo el $count restante';
  }

  @override
  String get batchRunUndoCompleted => 'Deshacer cambios de nombre completados';

  @override
  String get batchRunDone => 'Hecho';

  @override
  String get codeEditorTitle => 'Editar valor de parámetro';

  @override
  String get codeEditorFormat => 'Formato';

  @override
  String get codeEditorCancel => 'Cancelar';

  @override
  String get codeEditorConfirm => 'DE ACUERDO';

  @override
  String get codeEditorInvalidJson =>
      'JSON no válido. Arréglalo antes de guardar.';

  @override
  String get codeEditorParamPath =>
      'Ruta del nombre del parámetro (ampliada a JSON anidado cuando se envía)';

  @override
  String codeEditorErrorPosition(String line, String column, String message) {
    return 'Línea $line, columna $column: $message';
  }

  @override
  String codeEditorJsonError(String message) {
    return 'Error de formato JSON: $message';
  }

  @override
  String get codeEditorInvalidFormat => 'Formato JSON no válido';

  @override
  String get toolCallCompacted => 'Comprimido';

  @override
  String get mermaidSaveEmpty =>
      'El código de sirena está vacío. Nada que salvar.';

  @override
  String mermaidFolderLoadFailed(String error) {
    return 'No se pudieron cargar carpetas: $error';
  }

  @override
  String get mermaidSaveTitle => 'Guardar diagrama de sirena';

  @override
  String get mermaidSaveHint => 'Elija o cree una carpeta para el archivo .mmd';

  @override
  String get mermaidSaveFilenameHint =>
      'Ingrese un nombre de archivo (.mmd se agrega automáticamente)';

  @override
  String get mermaidFilenameEmpty =>
      'El nombre del archivo no puede estar vacío';

  @override
  String mermaidSaveSuccess(String folder, String name) {
    return 'Guardado en almacenamiento de texto: $folder/$name.mmd';
  }

  @override
  String mermaidSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get mermaidPrepareEngine => 'Preparando motor de renderizado...';

  @override
  String get mermaidRetry => 'Rever';

  @override
  String get batchRuleEmpty => 'no puede estar vacio';

  @override
  String get batchRuleNumber => 'Introduce un número';

  @override
  String get batchRulePositive => 'Introduzca un número mayor que 0';

  @override
  String batchRuleMin(String min) {
    return 'Debe ser al menos $min';
  }

  @override
  String batchRuleMax(String max) {
    return 'No debe ser mayor que $max';
  }

  @override
  String get batchRulePrefix => 'Prefijo';

  @override
  String get batchRuleSuffix => 'Sufijo';

  @override
  String get batchRuleStart => 'Comenzar';

  @override
  String get batchRuleStep => 'Paso';

  @override
  String get batchRuleDigits => 'Dígitos';

  @override
  String get batchRuleSeparator => 'Separador';

  @override
  String get batchRuleRestartFolder =>
      'Reiniciar la numeración en cada carpeta.';

  @override
  String get batchRuleNumberHelp =>
      'Los números siguen el orden de vista previa; Los elementos excluidos no utilizan un número. El paso puede ser negativo o 0.';

  @override
  String get batchRuleFind => 'Encontrar';

  @override
  String get batchRuleReplace => 'Reemplazar con (dejar vacío para eliminar)';

  @override
  String get batchRuleCaseSensitive => 'Distingue mayúsculas y minúsculas';

  @override
  String get batchRuleRegex => 'expresión regular';

  @override
  String get batchRuleFirstOnly => 'Reemplazar solo la primera coincidencia';

  @override
  String get batchRuleRegexHelp =>
      'Grupos de captura: \$1, \$2; partido completo: \$0; literal \$: \$\$. Ejemplo: ^IMG_(\\d+)\$ → Foto_\$1';

  @override
  String get batchRuleFindRequired =>
      'Ingrese el texto que desea buscar para habilitar esta regla.';

  @override
  String get batchRuleBeginning => 'Comienzo';

  @override
  String get batchRuleEnd => 'Fin';

  @override
  String get batchRulePosition => 'Posición';

  @override
  String get batchRuleInsertText => 'Texto para insertar';

  @override
  String get batchRuleBeforeChar => 'Antes del personaje N';

  @override
  String get batchRulePositionHelp =>
      'Las posiciones comienzan en 1; se añaden los valores más allá del final. Los emoji combinados cuentan como un carácter.';

  @override
  String get batchRuleFromBeginning => 'Desde el principio';

  @override
  String get batchRuleFromEnd => 'desde el final';

  @override
  String get batchRuleFromChar => 'Comenzando en el carácter N';

  @override
  String get batchRuleCount => 'Contar';

  @override
  String get batchRuleDeleteHelp =>
      'Si la eliminación vacía el nombre, una regla de inserción posterior debe agregar texto antes de la ejecución.';

  @override
  String get batchRuleUpper => 'MAYÚSCULAS';

  @override
  String get batchRuleLower => 'minúscula';

  @override
  String get batchRuleFirstUpper => 'Poner en mayúscula la primera letra';

  @override
  String get batchRuleTitleCase => 'Ponga en mayúscula cada palabra';

  @override
  String get batchRuleTemplate => 'Nueva plantilla de nombre';

  @override
  String batchRuleTemplateHint(String n, String name) {
    return 'Curso_${n}_$name';
  }

  @override
  String batchRuleTemplateHelp(
    String name,
    String n,
    String folder,
    String created,
    String modified,
    String ext,
  ) {
    return 'Nombre original $name · Secuencia $n · Nombre de carpeta $folder\n$created fecha de creación · $modified fecha de modificación · $ext extensión original\nFormato de fecha AAAA-MM-DD; Se informan las fechas faltantes. La plantilla reemplaza el nombre base completo; la extensión se mantiene automáticamente.';
  }

  @override
  String get batchRuleTrim => 'Recortar espacios iniciales y finales';

  @override
  String get batchRuleCollapseSpaces =>
      'Reemplazar espacios consecutivos con un espacio';

  @override
  String get batchRuleActions => 'Acciones de reglas';

  @override
  String get batchRuleDuplicate => 'Regla duplicada';

  @override
  String get batchRuleRemove => 'Eliminar regla';

  @override
  String get batchRuleMoveUp => 'Mover regla hacia arriba';

  @override
  String get batchRuleMoveDown => 'Mover regla hacia abajo';

  @override
  String get batchDlgSavePreset => 'Guardar preestablecido';

  @override
  String get batchDlgPresetName => 'Nombre preestablecido';

  @override
  String get batchDlgPresetHint =>
      'Guarda reglas y orden, pero no exclusiones ni nombres manuales.';

  @override
  String get batchDlgCancel => 'Cancelar';

  @override
  String get batchDlgSave => 'Guardar';

  @override
  String get batchDlgOverwriteTitle =>
      '¿Sobrescribir el ajuste preestablecido existente?';

  @override
  String batchDlgOverwriteBody(String name) {
    return 'Actualice las reglas en “$name”.';
  }

  @override
  String get batchDlgOverwrite => 'Exagerar';

  @override
  String get batchDlgManagePresets => 'Administrar ajustes preestablecidos';

  @override
  String get batchDlgNoPresets => 'No hay ajustes preestablecidos guardados';

  @override
  String get batchDlgDeletePreset => 'Eliminar preajuste';

  @override
  String get batchDlgDone => 'Hecho';

  @override
  String get batchDlgEditName => 'Editar nombre individualmente';

  @override
  String get batchDlgBaseName => 'Nombre básico';

  @override
  String get batchDlgOverrideHelp =>
      'Este nombre anula el resultado de la regla.';

  @override
  String batchDlgExtensionRetained(String extension) {
    return 'La extensión .$extension se mantiene automáticamente';
  }

  @override
  String get batchDlgConfirm => 'Confirmar';

  @override
  String get batchDlgHelp => 'Instrucciones';

  @override
  String get batchDlgClose => 'Cerrar';

  @override
  String get batchDlgLoadPreset =>
      'Cargar preset (reemplaza reglas y borra nombres manuales)';

  @override
  String get batchDlgLoad => 'Cargar preajuste';

  @override
  String get batchDlgSaving => 'Ahorro…';

  @override
  String get batchDlgReset =>
      'Restablecer todas las reglas y elementos incluidos';

  @override
  String get batchDlgRuleInstructions =>
      'Las reglas van de arriba a abajo. Cópielos, muévalos o deshabilítelos. Las extensiones de archivos permanecen sin cambios.';

  @override
  String get batchDlgSortName => 'Nombre';

  @override
  String get batchDlgSortCreated => 'Creado';

  @override
  String get batchDlgSortModified => 'Modificado';

  @override
  String get batchDlgSortSize => 'Tamaño';

  @override
  String get batchDlgAscending => 'Ascendente';

  @override
  String get batchDlgDescending => 'Descendente';

  @override
  String get batchDlgFolderSort =>
      'Las carpetas son lo primero; Los mismos nombres están ordenados por carpeta.';

  @override
  String get batchDlgAddRule => '＋ Agregar regla';

  @override
  String get batchDlgMaxRules => 'Máximo 50 reglas';

  @override
  String get batchDlgPreviewWorking =>
      'Calculando la vista previa... Puedes seguir editando reglas o cancelar.';

  @override
  String get batchDlgSearch => 'Buscar nombre original, nombre nuevo o carpeta';

  @override
  String get batchDlgFilterAll => 'Todo';

  @override
  String get batchDlgFilterChanged => 'Cambió';

  @override
  String get batchDlgFilterErrors => 'Asuntos';

  @override
  String get batchDlgFilterUnchanged => 'Sin alterar';

  @override
  String get batchDlgFilterExcluded => 'excluido';

  @override
  String get batchDlgParticipants => 'Elija artículos incluidos';

  @override
  String get batchDlgIncludeAll => 'incluir todo';

  @override
  String get batchDlgOnlyFiles => 'Sólo archivos';

  @override
  String get batchDlgOnlyFolders => 'Solo carpetas';

  @override
  String get batchDlgExcludeAll => 'Excluir todo';

  @override
  String get batchDlgScope => 'Artículos incluidos';

  @override
  String get batchDlgCopyList => 'Copiar lista';

  @override
  String get batchDlgConflictBlock =>
      'Conflicto de nombre: ejecución de bloque';

  @override
  String get batchDlgConflictSuffix =>
      'Conflicto de nombres: agregar (2), (3)…';

  @override
  String get batchDlgNoMatches => 'Ningún artículo coincide con el filtro';

  @override
  String get batchDlgRoot => 'Raíz';

  @override
  String get batchDlgFile => 'Archivo';

  @override
  String get batchDlgFolder => 'Carpeta';

  @override
  String batchDlgTargetFolder(String folder) {
    return 'Carpeta de destino: $folder';
  }

  @override
  String get batchDlgEditNameTooltip => 'Editar nombre individualmente';

  @override
  String get batchDlgRestoreNameTooltip =>
      'Restaurar el nombre generado por la regla';

  @override
  String get batchDlgCopied => 'Lista de vista previa completa copiada (CSV)';

  @override
  String get batchDlgCopyFailed => 'La copia falló. Intentar otra vez.';

  @override
  String get batchDlgHelpTitle =>
      'Instrucciones para cambiar el nombre por lotes';

  @override
  String get batchDlgHelpDismiss => 'Entiendo';

  @override
  String get batchDlgRulesTab => 'Normas';

  @override
  String batchDlgPreviewTab(String count) {
    return 'Vista previa ($count)';
  }

  @override
  String batchDlgRenameCount(String count) {
    return 'Cambiar el nombre de los elementos $count';
  }

  @override
  String get batchDlgPresetLoadFailed =>
      'No se pudieron cargar los ajustes preestablecidos. Aún puedes editar y ejecutar reglas.';

  @override
  String get batchDlgPreviewFailed =>
      'No se pudo calcular la vista previa. Ajusta las reglas y vuelve a intentarlo.';

  @override
  String batchDlgSavedName(String name) {
    return 'Preajuste guardado: $name';
  }

  @override
  String batchDlgSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get batchDlgPresetWriteFailed =>
      'No se pudo guardar el ajuste preestablecido.';

  @override
  String batchDlgDeleteFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String get batchDlgSavePresetFallback => 'Guardar preestablecido';

  @override
  String batchDlgPreviewSummary(
    String changes,
    String conflicts,
    String excluded,
  ) {
    return 'Vista previa · Cambios en $changes · Problemas con $conflicts · $excluded excluido';
  }

  @override
  String get batchDlgInvalidInput =>
      'Corregir entradas de reglas no válidas. La vista previa aún no los incluye.';

  @override
  String get batchDlgConflictError =>
      'Los conflictos o los nombres no válidos impiden la aplicación. Ajusta las reglas.';

  @override
  String get batchDlgManualNameStatus => 'Nombre manual';

  @override
  String get batchDlgPendingRename => 'Listo para cambiar el nombre';

  @override
  String get batchDlgCsvHeader =>
      'Ruta original,Nombre original,Ruta de destino,Estado';

  @override
  String get batchDlgHelpBody =>
      '1. Elija un ajuste preestablecido o habilite reglas, luego copie las reglas y ajuste su orden según sea necesario.\n\n2. La vista previa muestra los nombres que se utilizarán. La búsqueda y los filtros afectan solo la visualización. Desmarcar un elemento lo excluye y recalcula la numeración. Edite un nombre individualmente o restaure el resultado de la regla.\n\n3. Resuelva todos los problemas antes de ejecutar. Los sufijos automáticos manejan nombres duplicados sin sobrescribir archivos. Cambie el nombre de las carpetas que intercambian nombres en lotes separados.\n\n4. Puede detener elementos posteriores durante la ejecución; el elemento actual termina primero. La página de resultados muestra los cambios completados y le permite deshacerlos. Deshacer se bloquea si la lista ha cambiado desde la ejecución.\n\nEsto cambia únicamente los nombres y las rutas de las carpetas; El contenido y las extensiones del archivo permanecen sin cambios. Cambiar el nombre de una carpeta principal no impide que se cambie el nombre de los elementos secundarios marcados, y cambiar el nombre de un elemento principal mueve a sus elementos secundarios con él.';

  @override
  String batchDlgPreviewCount(String count) {
    return 'Vista previa ($count)';
  }

  @override
  String get batchBuiltinPhoto => 'Fotos: fecha y número';

  @override
  String get batchBuiltinCourse => 'Cursos: nombre y número consistentes';

  @override
  String get batchBuiltinDownloads => 'Descargas: limpiar espacios en blanco';

  @override
  String get taskListDetail => 'Detalles';

  @override
  String get taskListOwnershipChecking => 'Confirmar la propiedad de la tarea';

  @override
  String get taskListOwnershipFailed =>
      'No se pudo leer el registro de flujo de tareas; las acciones no están disponibles';

  @override
  String get taskListViewFlow => 'Ver flujo de tareas';

  @override
  String get taskListPause => 'Pausa';

  @override
  String get taskListClear => 'Borrar tarea';

  @override
  String get taskListResume => 'Reanudar';

  @override
  String get taskListRetry => 'Rever';

  @override
  String get taskListDismissError => 'Descartar error';

  @override
  String get taskListRemove => 'Eliminar de la lista';

  @override
  String get taskListSynthesisErrorTitle => 'Detalles del error de síntesis';

  @override
  String get taskListClose => 'Cerrar';

  @override
  String get taskListOriginalExchange => 'Solicitud y respuesta originales';

  @override
  String get taskListOriginalRequest => 'Cuerpo de la solicitud original:';

  @override
  String get taskListOriginalResponse => 'Cuerpo de respuesta original:';

  @override
  String get taskFlowIoTypeText => 'Texto';

  @override
  String get taskFlowIoTypeAudio => 'Audio';

  @override
  String get taskFlowIoTypeVideo => 'Video';

  @override
  String get taskFlowIoTypeImage => 'Imagen';

  @override
  String get taskFlowIoTypeLink => 'Enlace';

  @override
  String get taskFlowIoTypeFile => 'Archivo';

  @override
  String get taskFlowIoTypeAny => 'Cualquier';

  @override
  String get mermaidZoomOut => 'alejar';

  @override
  String get mermaidZoomIn => 'Dar un golpe de zoom';

  @override
  String get mermaidFullscreen => 'Pantalla completa';

  @override
  String get mermaidSaveButton => 'Guardar';

  @override
  String get mermaidSourceButton => 'Ver fuente';

  @override
  String get mermaidDiagramSemantic => 'Ver diagrama';

  @override
  String get taskFlowCardCatCatchDeletePersistError =>
      'No se pudo guardar el estado de eliminación de la tarea secundaria de CatCatch. Intentar otra vez.';

  @override
  String get taskFlowCardSynthesisDeletePersistError =>
      'No se pudo guardar el estado de eliminación de la tarea secundaria de síntesis. Intentar otra vez.';

  @override
  String get taskFlowCardBackgroundDeletePersistError =>
      'No se pudo guardar el estado de eliminación de la tarea secundaria en segundo plano. Intentar otra vez.';

  @override
  String get mathParseError => 'Error de análisis matemático';

  @override
  String get mermaidEmptyPlaceholder =>
      'No hay código de sirena para renderizar';

  @override
  String get mathClose => 'Cerrar';

  @override
  String get mermaidLoadTimeout =>
      'Se agotó el tiempo de carga de la sirena. Verifique su red e inténtelo nuevamente.';

  @override
  String get mermaidCdnLoadFailed =>
      'No se pudo acceder a cdn.jsdelivr.net para cargar Mermaid.';

  @override
  String get mermaidLoadingDiagram => 'Cargando diagrama…';

  @override
  String get mermaidEngineInitFailed =>
      'No se pudo inicializar el renderizador de diagramas. Intentar otra vez.';

  @override
  String get mermaidPageTimeout =>
      'Se agotó el tiempo de carga de la página. Intentar otra vez.';

  @override
  String get mermaidCodeLoadFailed =>
      'No se pudo cargar el código del diagrama. Intentar otra vez.';

  @override
  String mermaidPageLoadFailed(String description) {
    return 'Error al cargar la página: $description';
  }

  @override
  String get mermaidLoadingEngine => 'Cargando motor de renderizado…';

  @override
  String get mermaidRenderErrorTitle => 'Error de representación del diagrama';

  @override
  String get taskFlowOutputVideoAudioDownstream =>
      'Vídeo o audio (filtrado por downstream)';

  @override
  String get taskFlowOutputUnknown => 'Desconocido';

  @override
  String batchRunCancelledSummary(
    String label,
    String completed,
    String failed,
    String remaining,
  ) {
    return '$label se detuvo: $completed tuvo éxito, $failed falló, $remaining restante';
  }

  @override
  String mermaidRenderErrorPrefix(String message) {
    return 'Error de renderizado de sirena: $message';
  }

  @override
  String mermaidInitializeErrorPrefix(String message) {
    return 'Error de inicialización de sirena: $message';
  }

  @override
  String get mermaidResourceError =>
      'No se pudo cargar un recurso en el diagrama de Mermaid.';

  @override
  String get taskFlowParamRecognitionModel => 'Modelo de reconocimiento';

  @override
  String get taskFlowParamSynthesisModel => 'Modelo de síntesis';

  @override
  String get taskFlowParamSaveFolder => 'Guardar carpeta';

  @override
  String get taskFlowParamResourceSelection => 'Selección de recursos';

  @override
  String get taskFlowParamOutputType => 'Tipo de salida';

  @override
  String get taskFlowParamVideoFolder => 'Carpeta para guardar vídeos';

  @override
  String get taskFlowParamAudioFolder => 'Carpeta para guardar audio';

  @override
  String get taskFlowParamExpectedDuration => 'Duración esperada';

  @override
  String get taskFlowParamVoice => 'Voz';

  @override
  String get taskFlowParamSpeechRate => 'Velocidad del habla';

  @override
  String get taskFlowParamAssistant => 'Asistente';

  @override
  String get taskFlowHintResourceSelection =>
      'El modo manual te permite elegir. El modo automático sigue las reglas existentes. Preguntar cuando ambiguo selecciona automáticamente solo cuando hay una opción segura; de lo contrario, abre la lista de recursos para su confirmación.';

  @override
  String get taskFlowHintOutputType =>
      'Elija video o audio explícitamente. Siga los recursos de filtros posteriores según el tipo de entrada del siguiente bloque. Si el siguiente bloque acepta ambos tipos o no hay un siguiente bloque, se mantienen ambos tipos.';

  @override
  String get taskFlowHintExpectedDuration =>
      'Filtrar recursos por duración del video. Déjelo en blanco para omitir el filtrado.';

  @override
  String get taskFlowHintVoice =>
      'Elige una voz. El modelo de síntesis coincidente se selecciona automáticamente.';

  @override
  String get taskFlowUiUnsupportedBlockStep =>
      'Este tipo de bloque ya no es compatible. Reemplácelo o elimine este paso.';

  @override
  String taskFlowUiDownstreamTypeMismatch(String requiredType) {
    return 'El siguiente bloque requiere $requiredType. El descargador puede generar video o audio. Cambie el siguiente paso o política de salida.';
  }

  @override
  String taskFlowUiAnyTypeMismatch(String source, String block) {
    return '$source tiene cualquier tipo, pero “$block” necesita un tipo de texto, enlace, imagen, audio, video o archivo explícito. Cambie el tipo de entrada, mueva o reemplace el bloque, o deshaga el cambio.';
  }

  @override
  String taskFlowUiTypeMismatch(
    String source,
    String actualType,
    String block,
    String requiredType,
  ) {
    return '$source tiene $actualType, pero “$block” requiere $requiredType. Cambie el tipo de entrada, mueva o reemplace el bloque, o deshaga el cambio.';
  }

  @override
  String get fileManagerSortFieldCreated => 'Fecha de creación';

  @override
  String get fileManagerSortFieldModified => 'Fecha de modificación';

  @override
  String get fileManagerSortFieldName => 'Nombre';

  @override
  String get fileManagerSortFieldSize => 'Tamaño';

  @override
  String get fileManagerSortDateNewest => 'lo nuevo primero';

  @override
  String get fileManagerSortDateOldest => 'el mayor primero';

  @override
  String get fileManagerSortSizeLargest => 'más grande primero';

  @override
  String get fileManagerSortSizeSmallest => 'el más pequeño primero';

  @override
  String get catcatchStatusRunning => 'Correr';

  @override
  String get catcatchStatusCompleted => 'Terminado';

  @override
  String get catcatchStatusFailed => 'Fallido';

  @override
  String get catcatchStatusPaused => 'En pausa';

  @override
  String get catcatchStatusWaiting => 'Espera';

  @override
  String get catcatchStepFetching => 'Obteniendo página web';

  @override
  String get catcatchStepAnalyzing => 'Analizando medios';

  @override
  String get catcatchStepParsingPlaylist => 'Analizando lista de reproducción';

  @override
  String get catcatchStepFiltering => 'Filtrar por duración';

  @override
  String get catcatchStepUserSelecting => 'Esperando la selección';

  @override
  String get catcatchStepDownloading => 'Descargando';

  @override
  String get catcatchStepConverting => 'Convertir/fusionar';

  @override
  String get catcatchStepSaving => 'Guardar localmente';

  @override
  String get bgStepConnectServer => 'Conexión al servidor';

  @override
  String get bgStepUploadImage => 'Subiendo imágenes';

  @override
  String get bgStepWaitRecognition => 'Esperando reconocimiento';

  @override
  String get bgStepParseResult => 'Resultado del análisis';

  @override
  String get bgStepSaveFile => 'Guardando archivo';

  @override
  String get bgStepUploadAudio => 'Subiendo audio';

  @override
  String get bgStepTranscribing => 'Transcribiendo';

  @override
  String get bgStepReceiveResult => 'Recibiendo resultado';

  @override
  String get bgStepSeparateAudio => 'Separando audio';

  @override
  String get bgStepSaveToFile => 'Guardar en archivo';

  @override
  String get bgStepSendRequest => 'Enviando solicitud';

  @override
  String get bgStepWaitReply => 'Esperando respuesta';

  @override
  String get fileManagerSortNameAscending => 'De la A a la Z';

  @override
  String get fileManagerSortNameDescending => 'Z a A';

  @override
  String get taskFlowValidationNoSteps =>
      'Este flujo de tareas no tiene pasos. Primero agrega un bloque.';

  @override
  String get taskFlowValidationInputRequired =>
      'Agregue al menos una entrada para ejecutar este flujo de tareas.';

  @override
  String get taskFlowValidationFlowRemoved =>
      'Este flujo de tareas fue eliminado. Selecciónelo nuevamente.';

  @override
  String get taskFlowValidationInputTypeChanged =>
      'El tipo de entrada inicial cambió. Elija la entrada de ejecución nuevamente.';

  @override
  String get taskFlowValidationSnapshotMissing =>
      'Este registro anterior no tiene una instantánea de ejecución. Vuelva a intentar utilizar la configuración más reciente.';

  @override
  String get taskFlowValidationAssistantModelMissing =>
      'El modelo de asistente falta o no está disponible. Seleccione un modelo en la página de chat o establezca un modelo predeterminado para el asistente.';

  @override
  String get taskFlowValidationSavedFileUnavailable =>
      'Falta un archivo de pasos guardado, está vacío o es ilegible. Ejecute el flujo de tareas nuevamente.';

  @override
  String get taskFlowValidationUnsupportedBlock =>
      'Este tipo de bloque ya no es compatible. Reemplace o elimine este paso.';

  @override
  String taskFlowValidationDownstreamMismatch(String requiredType) {
    return 'El siguiente bloque requiere $requiredType. El descargador puede generar audio o video. Cambie el siguiente paso o política de salida.';
  }

  @override
  String taskFlowValidationRequiredParameter(String parameter, String block) {
    return 'Se requiere “$parameter” para “$block”. Configúrelo en la configuración del bloque.';
  }

  @override
  String taskFlowValidationLegacyModel(String block) {
    return 'La selección del modelo heredado necesita confirmación. Elija el modelo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationModelUnavailable(String block) {
    return 'El modelo falta o no está disponible por parte de su proveedor. Elíjalo nuevamente en la configuración de “$block” y verifique la URL y la clave del proveedor.';
  }

  @override
  String taskFlowValidationAssistantUnavailable(String block) {
    return 'El asistente falta o fue eliminado. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String get taskFlowValidationAssistantModelUnavailable =>
      'El modelo de asistente fue eliminado o su configuración de proveedor no está disponible. Elija un modelo nuevamente en la configuración del asistente.';

  @override
  String taskFlowValidationPolicyInvalid(String block) {
    return 'La política de selección de recursos o el tipo de salida no son válidos. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationOutputInvalid(String block) {
    return 'El tipo de salida no es válido. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationResourcePolicyInvalid(String block) {
    return 'La política de selección de recursos no es válida. Elíjalo nuevamente en la configuración “$block”.';
  }

  @override
  String taskFlowValidationInputFileUnavailable(String index) {
    return 'Entrada $index: El archivo falta, está vacío o es ilegible. Elígelo de nuevo.';
  }

  @override
  String taskFlowValidationInputUrlInvalid(String index) {
    return 'Ingrese $index: Ingrese un enlace HTTP o HTTPS válido.';
  }

  @override
  String taskFlowValidationInputError(String index, String error) {
    return 'Entrada $index: $error';
  }

  @override
  String get batchRuleValidationMaxRules =>
      'Se permiten como máximo 50 reglas.';

  @override
  String get batchRuleValidationDigits =>
      'El número de dígitos debe ser del 1 al 12.';

  @override
  String get batchRuleValidationNumberRange =>
      'El número inicial y el paso deben estar dentro de ±999.999.999.';

  @override
  String get batchRuleValidationReplacementLength =>
      'La norma de sustitución es demasiado larga.';

  @override
  String get batchRuleValidationRegex => 'La expresión regular no es válida.';

  @override
  String get batchRuleValidationDeleteIndex =>
      'La posición de eliminación debe comenzar en 1.';

  @override
  String get batchRuleValidationInsertLength =>
      'El texto insertado es demasiado largo.';

  @override
  String get batchRuleValidationTemplateNumber =>
      'Configuración de número de plantilla no válida: los dígitos deben ser del 1 al 12 y el inicio/paso dentro de ±999,999,999.';

  @override
  String get batchRuleValidationTemplateLength =>
      'La plantilla es demasiado larga.';

  @override
  String get batchRuleValidationTemplateVariable =>
      'Variable de plantilla desconocida o llave abierta.';

  @override
  String get batchRuleTypeNumber => 'Añadir numeración';

  @override
  String get batchRuleTypeReplace => 'Buscar y reemplazar';

  @override
  String get batchRuleTypeInsert => 'Insertar texto';

  @override
  String get batchRuleTypeDelete => 'Eliminar caracteres';

  @override
  String get batchRuleTypeCase => 'Cambiar caso';

  @override
  String get batchRuleTypeTemplate => 'Plantilla de nombre';

  @override
  String get batchRuleTypeCleanup => 'Limpiar espacios en blanco';

  @override
  String taskFlowValidationInputEmpty(String index) {
    return 'Ingrese $index: ingrese texto o elija un archivo.';
  }

  @override
  String taskFlowValidationImageTooLarge(String index) {
    return 'Entrada $index: La imagen tiene más de 20 MB. Elija una imagen más pequeña.';
  }

  @override
  String taskFlowValidationAttachmentTooLarge(String index) {
    return 'Entrada $index: El archivo adjunto tiene más de 10 MB. Elija un archivo más pequeño.';
  }

  @override
  String taskFlowValidationFileTypeMismatch(
    String index,
    String actualType,
    String requiredType,
  ) {
    return 'Ingrese $index: el archivo es $actualType, pero se requiere $requiredType. Elija otro archivo.';
  }

  @override
  String taskFlowValidationSvgUnsupported(String index) {
    return 'Entrada $index: El chat del asistente no admite archivos adjuntos de imágenes SVG. Conviértelo a PNG o JPEG.';
  }

  @override
  String taskFlowValidationImageMimeUnsupported(String index, String mime) {
    return 'Entrada $index: El chat del asistente no admite archivos adjuntos de imágenes $mime. Conviértelo a PNG, JPEG, GIF o WebP.';
  }

  @override
  String taskFlowValidationAudioMimeUnsupported(String index, String mime) {
    return 'Entrada $index: El chat del asistente no admite archivos adjuntos de audio $mime. Conviértelo a MP3, WAV o M4A.';
  }

  @override
  String taskFlowValidationEndpointMediaUnsupported(String index, String type) {
    return 'Ingrese $index: este formato de chat antrópico no admite archivos adjuntos $type. Elija un asistente que admita este medio.';
  }

  @override
  String taskFlowValidationEndpointPdfOnly(String index) {
    return 'Ingrese $index: este formato de chat antrópico solo admite archivos adjuntos de imágenes y PDF. Elija un archivo compatible.';
  }

  @override
  String taskFlowValidationImageCompressionFailed(String index) {
    return 'Ingrese $index: El chat del asistente no pudo comprimir la imagen por debajo de 10 MB. Elija una imagen más pequeña.';
  }

  @override
  String taskFlowValidationTextEncodingFailed(String index) {
    return 'Entrada $index: El texto adjunto no es UTF-8 válido. Conviértelo e inténtalo de nuevo.';
  }

  @override
  String get assistantParamValueTypeString => 'Cadena';

  @override
  String get assistantParamValueTypeNumber => 'Número';

  @override
  String get assistantParamValueTypeBoolean => 'Booleano';

  @override
  String get assistantParamValueTypeJson => 'JSON';

  @override
  String get providerRequiredFields =>
      'Se requieren el nombre del proveedor, la URL de API y la clave.';

  @override
  String get providerJsonSizePositive =>
      'El tamaño JSON de la solicitud debe ser un valor MiB positivo.';

  @override
  String get providerCustomParamRequired =>
      'Se requieren el nombre y el valor del parámetro personalizado.';

  @override
  String providerParamNameInvalid(String name) {
    return 'El nombre del parámetro no es válido (los segmentos separados por puntos no pueden estar vacíos): $name';
  }

  @override
  String providerParamAlreadyExists(String name) {
    return 'El parámetro ya existe: $name';
  }

  @override
  String providerParamInvalidJson(String name, String value) {
    return 'El valor predeterminado para el parámetro \"$name\" no es válido JSON: $value';
  }

  @override
  String providerParamOptionsRequired(String name) {
    return 'Las opciones numéricas para el parámetro \"$name\" no pueden estar vacías.';
  }

  @override
  String providerParamInvalidNumber(String name, String value) {
    return 'El valor del parámetro \"$name\" no es un número válido: $value';
  }

  @override
  String get providerReasoningIncomplete =>
      'Complete la alternancia de razonamiento antes de habilitar otros parámetros de razonamiento.';

  @override
  String providerReasoningError(String error) {
    return 'Error de parámetro de razonamiento: $error';
  }

  @override
  String providerParamNameConflict(String name) {
    return 'Los parámetros de razonamiento y personalizados tienen el mismo nombre: $name';
  }

  @override
  String get providerMaxTokensMissing =>
      'Los tokens de salida máximos están habilitados, pero no se ingresó ningún valor.';

  @override
  String get providerMaxTokensPositive =>
      'Los tokens de salida máximos deben ser un número entero positivo.';

  @override
  String get providerSeedInteger =>
      'La semilla aleatoria debe ser un número entero.';

  @override
  String get providerNotConfigured => 'No establecido';

  @override
  String get providerAudioChunkingTitle => 'fragmentación de audio';

  @override
  String get providerAudioChunkingHint =>
      'La fragmentación inteligente analiza el audio y los cortes candidatos, prefiriendo las terminaciones de oraciones. Los trozos no se superponen.';

  @override
  String get providerChunkingMode => 'método de fragmentación';

  @override
  String get providerChunkNone => 'sin fragmentación';

  @override
  String get providerChunkSmart => 'Fragmentación inteligente (recomendado)';

  @override
  String get providerChunkFixedDuration => 'Fragmentos de duración fija';

  @override
  String get providerChunkFixedSize => 'Trozos de tamaño fijo';

  @override
  String get providerCompressionTitle => 'Codificación de compresión';

  @override
  String get providerCompressionHint =>
      'Cuando está habilitado, el respaldo general primero comprime el WAV completo. Si el archivo codificado o el cuerpo de la solicitud aún supera el límite, el PCM de origen se fragmenta y codifica.';

  @override
  String get providerCompressionMode => 'Método de compresión';

  @override
  String get providerCompressionNone => 'Ninguno (enviar tal cual)';

  @override
  String get providerCompressionAdpcm => 'ADPCM (~4x compresión)';

  @override
  String get providerCompressionFlac => 'FLAC (sin pérdidas, ~2x)';

  @override
  String get providerCompressionAdpcmDescription =>
      'IMA ADPCM, compresión 4:1 con pérdida. Implementación de Pure Dart; La calidad del audio se adapta a la transcripción.';

  @override
  String get providerCompressionFlacDescription =>
      'Compresión FLAC sin pérdidas, implementada en Dart puro. Reduce el tamaño aproximadamente a la mitad.';

  @override
  String get providerCompressionWavDescription =>
      'Sin compresión; enviar como un archivo WAV.';

  @override
  String get providerLlmParams => 'Parámetros del LLM';

  @override
  String get providerEnabledParamsHelp =>
      'Los parámetros habilitados se envían de forma predeterminada en las solicitudes de API.';

  @override
  String get providerTemperatureLabel => 'Temperatura';

  @override
  String get providerTemperatureHelp =>
      'Controla la aleatoriedad de la salida; Los valores más altos son más creativos.';

  @override
  String get providerTopPHelp =>
      'Parámetro de muestreo de núcleo que controla la probabilidad acumulada para la selección de palabras.';

  @override
  String get providerFrequencyPenaltyLabel => 'Penalización de frecuencia';

  @override
  String get providerFrequencyPenaltyHelp =>
      'Reduce las palabras repetidas; los valores negativos aumentan la repetición.';

  @override
  String get providerPresencePenaltyLabel => 'Penalización de presencia';

  @override
  String get providerPresencePenaltyHelp =>
      'Fomenta nuevos temas; los valores negativos alientan a volver a temas anteriores.';

  @override
  String get providerMaxOutputTokensLabel => 'Tokens de salida máximos';

  @override
  String providerOptionalExample(String example) {
    return 'Opcional, p.e. $example';
  }

  @override
  String get providerResponseTokensHelp =>
      'Número máximo de tokens generados por respuesta.';

  @override
  String get providerSeedLabel => 'semilla aleatoria';

  @override
  String get providerSeedHelp =>
      'Configúrelo para que la salida sea reproducible.';

  @override
  String get providerChunkSmartDescription =>
      'Analiza cortes de audio y candidatos, prefiriendo finales de oración o silencios largos sin superposición. Valores predeterminados: 20 s mínimo / 45 s objetivo / 60 s máximo. Utilizado sólo por el respaldo general; La fragmentación de compresión solo admite PCM WAV.';

  @override
  String get providerChunkDurationDescription =>
      'Se divide cada N segundos (60 por defecto). Simple, pero puede cortar el habla. Utilizado sólo por el respaldo general; La fragmentación de compresión solo admite PCM WAV.';

  @override
  String get providerChunkSizeDescription =>
      'Inicialmente se divide por tamaño de datos de audio, luego se refina por archivo codificado y tamaño del cuerpo de la solicitud. Utilizado sólo por el respaldo general; La fragmentación de compresión solo admite PCM WAV.';

  @override
  String get providerChunkNoneDescription =>
      'Sin fragmentación. El archivo se rechaza si excede el límite después de la compresión completa.';

  @override
  String get providerNameLabel => 'Nombre del proveedor';

  @override
  String get providerNameHint => 'Introduzca el nombre del proveedor';

  @override
  String get providerApiUrlLabel => 'URL de la API';

  @override
  String get providerApiUrlHint =>
      'Ingrese la URL completa del punto final de la API';

  @override
  String providerApiKeyHint(String hint) {
    return 'Pista: $hint';
  }

  @override
  String get providerEndpointTypeLabel => 'Tipo de punto final';

  @override
  String get providerEndpointOpenAi =>
      'Compatible con OpenAI (finalizaciones de chat)';

  @override
  String get providerEndpointAnthropic => 'Formato antrópico (API de mensajes)';

  @override
  String get providerAnthropicEndpointHelp =>
      'Utiliza el formato API oficial de Anthropic Messages (encabezado x-api-key). Ejemplo de URL de API: https://api.anthropic.com/v1/messages';

  @override
  String get providerOpenAiEndpointHelp =>
      'Utiliza el formato oficial compatible con OpenAI Chat Completions (encabezado de portador). Ejemplo de URL de API: https://api.openai.com/v1/chat/completions';

  @override
  String get providerRequestJsonDefault =>
      'Tamaño JSON de solicitud predeterminado';

  @override
  String get providerUseAppDefault =>
      'Déjelo vacío para usar la aplicación predeterminada';

  @override
  String get providerModelJsonBudgetHelp =>
      'Los modelos pueden anular este valor. Si ni el proveedor ni el modelo lo configuran, el valor predeterminado es 20 MiB.';

  @override
  String get providerRequestParamsHelp =>
      'Las solicitudes utilizan todos los parámetros de modelo y proveedor habilitados. Cuando los nombres se superponen, el valor del modelo tiene prioridad.';

  @override
  String get providerUploadSettings => 'Cargar configuración';

  @override
  String get providerUploadMethodHelp =>
      'Los métodos de carga de audio y los límites de tamaño varían según el proveedor.';

  @override
  String get providerUploadMethod => 'Método de carga';

  @override
  String get providerMultipart => 'Multiparte (general)';

  @override
  String get providerUrlUpload => 'URL';

  @override
  String get providerMaxUploadSize => 'Tamaño máximo de carga';

  @override
  String get providerFallbackStrategy => 'estrategia alternativa';

  @override
  String get providerFallbackMethod => 'Método alternativo';

  @override
  String get providerPreprocessing => 'Preprocesamiento de audio';

  @override
  String get providerPreprocessingHelp =>
      'Reduce el tamaño del archivo de audio sin afectar la precisión de la transcripción.';

  @override
  String get providerPreprocessingMethod => 'Método de preprocesamiento';

  @override
  String get providerUploadMultipartHelp =>
      'Carga directa de datos de formulario/multiparte. El cuerpo de la solicitud incluye audio, campos de formulario y límites de varias partes.';

  @override
  String get providerUploadBase64Help =>
      'Envía Base64 en JSON, lo que puede eludir los límites específicos de varias partes de algunos proveedores. La expansión Base64 y los campos JSON cuentan para el límite de carga.';

  @override
  String get providerUploadUrlHelp =>
      'Proporcione una URL pública para que el proveedor la descargue. Admite archivos muy grandes (por ejemplo, Together AI 1 GB).';

  @override
  String get providerUploadBudgetHelp =>
      'Este valor desencadena una reserva de audio sin formato y limita el cuerpo de la solicitud final. La aplicación verifica el audio sin procesar, los archivos codificados y el tamaño de carga. Multiparte incluye campos y límites de formulario; Base64 JSON incluye campos y expansión de codificación. El valor predeterminado de 25 MB coincide con el límite de la API de audio de OpenAI.';

  @override
  String get providerFallbackTriggerHelp =>
      'Se activa cuando el audio sin procesar o el cuerpo completo de la solicitud excede su límite. El respaldo específico (Base64) tiene prioridad sobre el respaldo general (compresión/fragmentación).';

  @override
  String get providerFallbackNone => 'Ninguno (rechazar inmediatamente)';

  @override
  String get providerFallbackSpecific => 'Respaldo específico (Base64)';

  @override
  String get providerFallbackGeneric =>
      'Respaldo general (compresión/fragmentación)';

  @override
  String get providerFallbackAll => 'Pruebe todo (recomendado)';

  @override
  String get providerFallbackSpecificHelp =>
      'Pruebe Base64 JSON. Envíe solo si el cuerpo de la solicitud, incluida la expansión Base64 y los campos JSON, se ajusta al límite.';

  @override
  String get providerFallbackGenericHelp =>
      'Si está habilitado, comprima primero el WAV completo. Si aún excede el límite y la fragmentación está habilitada, divida el PCM de origen y codifique cada fragmento. Sólo PCM WAV.';

  @override
  String get providerFallbackAllHelp =>
      'Pruebe primero Base64 dentro del límite del cuerpo de la solicitud. Luego, si está habilitado, comprima el WAV completo; Si aún excede el límite y la fragmentación está habilitada, divida el PCM de origen y codifique cada fragmento. Sólo PCM WAV.';

  @override
  String get providerFallbackRejectHelp =>
      'Rechazar el archivo si excede el límite; no intente una alternativa.';

  @override
  String get providerPreprocessNone => 'Ninguno';

  @override
  String get providerPreprocessResample => 'Optimización WAV (mono de 16 kHz)';

  @override
  String get providerPreprocessResampleHelp =>
      'Remuestrea a 16 kHz y mezcla en mono. Reduce el tamaño entre 4 y 6 veces con poco efecto en la precisión de la transcripción.';

  @override
  String get providerPreprocessNoneHelp =>
      'Sin preprocesamiento; enviar tal cual.';

  @override
  String get assistantDefaultsScopeHelp =>
      'El modelo y las herramientas predeterminados se aplican solo a las nuevas conversaciones creadas con este asistente. Las conversaciones existentes mantienen su propia configuración. El truncamiento de salida de la herramienta se aplica a todas las conversaciones.';

  @override
  String get assistantDefaultModelTitle => 'Modelo predeterminado';

  @override
  String get assistantDefaultModelHelp =>
      'Modelo utilizado para nuevas conversaciones; déjelo sin configurar para dejar que la conversación elija.';

  @override
  String get assistantNoDefault => 'No establecido';

  @override
  String get assistantNoModelsAvailable =>
      'No hay modelos disponibles. Configure un proveedor de LLM en Configuración.';

  @override
  String get assistantDefaultToolsTitle =>
      'Herramientas habilitadas por defecto';

  @override
  String get assistantDisabledToolsHelp =>
      'Las herramientas deshabilitadas no se habilitarán automáticamente en nuevas conversaciones.';

  @override
  String get assistantUnconfiguredToolsHelp =>
      'Las herramientas predeterminadas no están configuradas. Las nuevas conversaciones habilitarán todas las herramientas automáticamente.';

  @override
  String get assistantEnableAll => 'Habilitar todo';

  @override
  String get assistantDisableAll => 'Desactivar todo';

  @override
  String get assistantNoToolsAvailable => 'No hay herramientas disponibles';

  @override
  String get assistantTruncateToolOutput =>
      'Truncamiento de salida de herramienta';

  @override
  String get assistantTruncateToolOutputHelp =>
      'Número máximo de caracteres en cada resultado de herramienta antes de enviarlo al modelo. Se aplica a todas las conversaciones bajo este asistente.';

  @override
  String get assistantEnableTruncation => 'Habilitar truncamiento';

  @override
  String assistantTruncatedTo(String count) {
    return 'Los resultados largos se truncan a caracteres $count';
  }

  @override
  String get assistantSendFullResult =>
      'Enviar resultado completo (sujeto al límite de almacenamiento de 50 KB)';

  @override
  String get assistantMaxCharacters => 'Caracteres máximos';

  @override
  String get assistantCharactersNotTokens => 'Unidad: personajes (no fichas)';

  @override
  String assistantDefaultCharacterCount(String count) {
    return 'Valor predeterminado: $count';
  }

  @override
  String assistantCharacterRange(String minimum, String maximum) {
    return 'Rango válido: caracteres $minimum–$maximum';
  }

  @override
  String get assistantNewConversationPreview =>
      'Vista previa de nueva conversación';

  @override
  String assistantEnabledToolCount(String enabled, String total) {
    return '$enabled / $total habilitado';
  }

  @override
  String get assistantAllToolsAutoEnabled =>
      'Todas las herramientas se habilitan automáticamente (no se configuran)';

  @override
  String get assistantMoreActions => 'Más acciones';

  @override
  String get assistantChooseEmoji => 'Elige emojis';

  @override
  String get assistantNameLabel => 'Nombre del asistente';

  @override
  String get assistantDescriptionOptional => 'Descripción (opcional)';

  @override
  String get assistantSelectionTitle => 'Elige un asistente';

  @override
  String get assistantMarketTooltip => 'Mercado asistente';

  @override
  String get assistantDefaultPrompt =>
      'Eres un útil asistente de IA. Responda las preguntas del usuario de forma clara y útil.';

  @override
  String get assistantCreateNew => 'Crear asistente';

  @override
  String get assistantEmptyState =>
      'Aún no hay asistentes. Crea uno para comenzar.';

  @override
  String get assistantCreate => 'Crear';

  @override
  String get assistantReorderHint =>
      'Mantenga presionado y arrastre para reordenar los asistentes';

  @override
  String get assistantNewNameHint => 'Introduzca el nombre del asistente';

  @override
  String get assistantNewDescriptionHint =>
      'Describe brevemente qué hace este asistente.';

  @override
  String get assistantDeleteTitle => 'Eliminar asistente';

  @override
  String assistantDeleteConfirmation(String name) {
    return '¿Eliminar asistente “$name”? Esta acción no se puede deshacer.';
  }

  @override
  String get assistantEditTitle => 'Asistente de edición';

  @override
  String get assistantBasicTab => 'Configuraciones básicas';

  @override
  String get assistantParametersTab => 'Parámetros';

  @override
  String get assistantDefaultsTab => 'Valores predeterminados';

  @override
  String get assistantAddCustomParameter => 'Agregar parámetro personalizado';

  @override
  String get assistantEditCustomParameter => 'Editar parámetro personalizado';

  @override
  String get assistantParameterName => 'Nombre del parámetro';

  @override
  String get assistantParameterNameHint => 'p.ej. top_k o proveedor.solo';

  @override
  String get assistantParameterNameInvalid =>
      'Nombre de parámetro no válido (los segmentos separados por puntos no pueden estar vacíos)';

  @override
  String get assistantParameterType => 'Tipo';

  @override
  String get assistantValue => 'Valor';

  @override
  String get assistantTrueFalseHint => 'verdadero o falso';

  @override
  String get assistantNumberHint => 'Introduce un número';

  @override
  String assistantJsonHint(String example) {
    return 'p.ej. $example';
  }

  @override
  String get assistantValueHint => 'Introduce un valor';

  @override
  String get assistantCancel => 'Cancelar';

  @override
  String get assistantSave => 'Guardar';

  @override
  String get assistantParamOverrideHelp =>
      'Cuando están habilitados, los parámetros del asistente anulan los parámetros del modelo; cuando está deshabilitado, se utilizan los parámetros del modelo.';

  @override
  String get assistantTemperature => 'Temperatura';

  @override
  String get assistantMaxTokens => 'Fichas máximas';

  @override
  String get assistantMaxToolCalls => 'Llamadas máximas a herramientas';

  @override
  String assistantRounds(String count) {
    return 'Rondas $count';
  }

  @override
  String get assistantUnlimited => 'Ilimitado';

  @override
  String get assistantStreamOutput => 'Salida de flujo';

  @override
  String get assistantFrequencyPenalty => 'Penalización de frecuencia';

  @override
  String get assistantPresencePenalty => 'Penalización de presencia';

  @override
  String get assistantRandomSeed => 'semilla aleatoria';

  @override
  String get assistantNotSet => 'No establecido';

  @override
  String get assistantSeedValue => 'Valor de la semilla';

  @override
  String get assistantIntegerSeedHint => 'Introduzca una semilla entera';

  @override
  String get assistantWebSearch => 'búsqueda web';

  @override
  String get assistantAddParameter => 'Agregar parámetro';

  @override
  String get assistantNoCustomParameters => 'Sin parámetros personalizados';

  @override
  String get assistantRoundsLabel => 'Rondas';

  @override
  String get modelCreateTitle => 'Agregar modelo';

  @override
  String get modelEditTitle => 'Editar modelo';

  @override
  String get modelDiscardTitle => '¿Descartar cambios?';

  @override
  String get modelDiscardBody => 'Tienes cambios sin guardar. ¿Descartarlos?';

  @override
  String get modelNameLabel => 'Nombre del modelo';

  @override
  String get modelNameHint => 'Ingrese un nombre para mostrar (opcional)';

  @override
  String get modelIdLabel => 'ID del modelo';

  @override
  String modelIdExample(String id) {
    return 'p.ej. $id';
  }

  @override
  String get modelIdRequired => 'Se requiere identificación del modelo.';

  @override
  String get modelCustomParamRequired =>
      'Se requieren el nombre del parámetro personalizado y el valor predeterminado.';

  @override
  String modelParamDuplicate(String name) {
    return 'El parámetro ya existe: $name';
  }

  @override
  String modelParamReserved(String name) {
    return 'Nombre del parámetro OCR reservado: $name';
  }

  @override
  String get modelParamName => 'Nombre del parámetro';

  @override
  String get modelParamDefaultValue => 'Valor de parámetro predeterminado';

  @override
  String get modelParamDelete => 'Eliminar parámetro';

  @override
  String modelParamJsonInvalid(String name, String value) {
    return 'El valor predeterminado para el parámetro \"$name\" no es válido JSON: $value';
  }

  @override
  String get modelAddParameter => 'Agregar parámetro';

  @override
  String get modelNoCustomParams => 'Sin parámetros personalizados';

  @override
  String get modelBasicSettings => 'Configuraciones básicas';

  @override
  String get modelDiscardCancel => 'Cancelar';

  @override
  String get modelSave => 'Guardar';

  @override
  String get modelUnsavedMaxTokens =>
      'Los tokens de salida máximos están habilitados pero no tienen valor.';

  @override
  String get modelMaxTokensPositive =>
      'Los tokens de salida máximos deben ser un número entero positivo.';

  @override
  String get modelSeedInteger =>
      'La semilla aleatoria debe ser un número entero.';

  @override
  String get modelContextLengthRequired => 'Se requiere longitud de contexto.';

  @override
  String get modelContextLengthPositive =>
      'La longitud del contexto debe ser un número entero positivo.';

  @override
  String get modelAsrLanguageCode => 'Código de idioma (Idioma)';

  @override
  String get modelAsrLanguageHint => 'p.ej. zh, en, ja';

  @override
  String get modelAsrLanguageHelp =>
      'Código de idioma ISO-639-1; déjelo vacío para la detección automática.';

  @override
  String get modelTemperature => 'Temperatura';

  @override
  String get modelTemperatureHelp =>
      'Controla la aleatoriedad de la salida; Se recomienda un valor más bajo.';

  @override
  String get modelAsrPrompt => 'Instrucción';

  @override
  String get modelAsrPromptHint => 'Ingrese un mensaje de contexto (opcional)';

  @override
  String get modelAsrPromptHelp =>
      'Proporcione contexto para mejorar la precisión de la transcripción, como una lista de términos especializados.';

  @override
  String get modelAsrParams => 'Parámetros ASR';

  @override
  String get modelEnabledParamsHelp =>
      'Los parámetros habilitados se envían de forma predeterminada en las solicitudes de API.';

  @override
  String get modelAsrResponseFormat => 'Formato de respuesta';

  @override
  String get modelAsrResponseHelp => 'Formato de la transcripción devuelta.';

  @override
  String get modelAsrTimestampGranularity =>
      'Granularidad de la marca de tiempo';

  @override
  String get modelAsrVerboseHelp =>
      'Disponible solo cuando el formato_respuesta es verbose_json.';

  @override
  String get modelNoTrim => 'Sin recortes';

  @override
  String get modelAudioTrimTitle => 'Recorte de audio';

  @override
  String get modelAudioTrimHelp => 'Elija cómo recortar el audio.';

  @override
  String get modelDeleteTrimPreset => 'Eliminar ajuste preestablecido';

  @override
  String modelDeleteTrimConfirmation(String name) {
    return '¿Eliminar ajuste preestablecido \"$name\"?';
  }

  @override
  String get modelAddTrimPreset => 'Agregar adornos personalizados';

  @override
  String get modelPlayTestAudio => 'Reproducir audio de prueba';

  @override
  String get modelPlayingTestAudio => 'Jugando...';

  @override
  String get modelParamExists => 'El parámetro ya existe';

  @override
  String get asrModelIdExample => 'p.ej. susurro-1';

  @override
  String get asrPromptLabel => 'Instrucción';

  @override
  String get asrResponseFormatJson => 'json-JSON';

  @override
  String get asrResponseFormatText => 'texto – texto sin formato';

  @override
  String get asrResponseFormatSrt => 'srt – Subtítulos';

  @override
  String get asrResponseFormatVtt => 'vtt – Subtítulos';

  @override
  String get asrResponseFormatVerbose =>
      'verbose_json: JSON detallado (incluye marcas de tiempo)';

  @override
  String get asrVerboseTimestampHelp =>
      'Al seleccionar verbose_json se habilita la opción de granularidad de marca de tiempo a continuación.';

  @override
  String get asrTimestampSegment => 'segmento – nivel de segmento';

  @override
  String get asrTimestampWord => 'palabra – nivel de palabra';

  @override
  String get asrWordTimestampHelp =>
      'Las marcas de tiempo a nivel de palabra pueden ser menos precisas que las marcas de tiempo a nivel de segmento.';

  @override
  String get reasoningAddOptionValue => 'Agregar valor de opción';

  @override
  String get reasoningEditOptionValue => 'Editar valor de opción';

  @override
  String get reasoningOptionExample => 'p.ej. bajo, medio, alto';

  @override
  String get reasoningOptionSelectionHelp =>
      'Toque un chip para seleccionarlo o borrarlo. Se envían los valores seleccionados; arrastre para reordenar. Los valores del proveedor no se pueden eliminar, pero se pueden ocultar al borrarlos.';

  @override
  String get reasoningAddOption => 'Agregar opción';

  @override
  String get reasoningCurrentProvider => 'Actual: proveedor';

  @override
  String get reasoningCurrentModel => 'Actual: modelo personalizado';

  @override
  String get reasoningAddEffortValue =>
      'Agregue valor al esfuerzo de razonamiento';

  @override
  String get reasoningEffortExample => 'p.ej. máximo, ultra, profundo';

  @override
  String get reasoningAddToggle => 'Agregar palanca de razonamiento';

  @override
  String get reasoningToggle => 'alternar razonamiento';

  @override
  String get reasoningResetParameter => 'Restablecer este parámetro';

  @override
  String get reasoningDisableToggle => 'Deshabilitar el cambio de razonamiento';

  @override
  String get reasoningEnableToggle => 'Habilitar alternancia de razonamiento';

  @override
  String reasoningParameterNameSource(String source) {
    return 'Nombre del parámetro ($source)';
  }

  @override
  String get reasoningNameExample => 'p.ej. tipo de pensamiento, razonamiento';

  @override
  String get reasoningBooleanHelp =>
      'Los parámetros booleanos no necesitan valor; el panel de chat proporciona un interruptor de encendido/apagado.';

  @override
  String get reasoningOnValue => 'Valor cuando está habilitado';

  @override
  String get reasoningOnExample => 'p.ej. habilitado, verdadero';

  @override
  String get reasoningOffValue => 'Valor cuando está deshabilitado';

  @override
  String get reasoningOffExample => 'p.ej. deshabilitado, falso';

  @override
  String reasoningToggleValuesHelp(String onValue, String offValue) {
    return 'Cuando está habilitado, envía “$onValue”; cuando está deshabilitado, envía “$offValue”.';
  }

  @override
  String get reasoningAddEffort => 'Añadir esfuerzo de razonamiento';

  @override
  String get reasoningFillToggleFirst =>
      'Primero complete el cambio de razonamiento';

  @override
  String get reasoningFillToggleBeforeEffort =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get reasoningAddValue => 'Agregar valor';

  @override
  String get reasoningJsonValue => 'valor JSON';

  @override
  String reasoningJsonExample(String example) {
    return 'p.ej. $example';
  }

  @override
  String get reasoningSelectedChipHelp =>
      'Toque un chip para seleccionarlo o borrarlo. Los valores seleccionados aparecen en el panel de razonamiento del chat; arrastre para reordenar. Los valores del proveedor no se pueden eliminar, pero se pueden ocultar.';

  @override
  String get reasoningAddParameter => 'Agregar parámetro de razonamiento';

  @override
  String get reasoningToggleIncomplete =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get llmContextLength => 'Longitud del contexto';

  @override
  String get llmContextHint => 'Introduzca la longitud del contexto';

  @override
  String get llmContextHelp =>
      'Tamaño máximo de ventana de contexto para el modelo (tokens).';

  @override
  String get llmReasoningParams => 'Parámetros de razonamiento';

  @override
  String get llmReasoningHelp =>
      'Configurar parámetros de razonamiento para el chat. La palanca de razonamiento controla el nombre del parámetro y los valores de activación/desactivación. Agregue valores de esfuerzo de razonamiento, reordenelos y seleccione qué valores aparecen en el panel de chat. Los valores del proveedor se sincronizan cuando se abre esta página. Estas configuraciones controlan la disponibilidad de los parámetros del modelo; la alternancia del panel de chat se administra por separado.';

  @override
  String get llmAddReasoningParam => 'Agregar parámetro de razonamiento';

  @override
  String get llmCustomEndpointType => 'Tipo de punto final personalizado';

  @override
  String get llmInheritEndpointType =>
      'Cuando esté deshabilitado, use el tipo de punto final de la configuración del proveedor.';

  @override
  String get llmEndpointType => 'Tipo de punto final';

  @override
  String get llmEndpointOpenAi =>
      'Compatible con OpenAI (finalizaciones de chat)';

  @override
  String get llmEndpointAnthropic => 'Formato antrópico (API de mensajes)';

  @override
  String get llmEndpointHelp =>
      'El tipo de punto final debe coincidir con la URL de la API del proveedor. Cambiarlo afecta el formato utilizado para nuevas conversaciones con este modelo.';

  @override
  String get llmTopPHelp =>
      'Parámetro de muestreo del núcleo; controla la probabilidad acumulada para la selección de palabras.';

  @override
  String get llmFrequencyPenaltyLabel => 'Penalización de frecuencia';

  @override
  String get llmFrequencyPenaltyHelp =>
      'Reduce la repetición; los valores negativos lo aumentan.';

  @override
  String get llmPresencePenaltyLabel => 'Penalización de presencia';

  @override
  String get llmPresencePenaltyHelp =>
      'Fomenta nuevos temas; los valores negativos fomentan la repetición.';

  @override
  String get llmMaxTokensHint => 'Opcional, p.e. 4096';

  @override
  String get llmTokensPerResponse => 'Tokens máximos generados por respuesta.';

  @override
  String get llmSeedLabel => 'Semilla aleatoria (Semilla)';

  @override
  String get llmSeedHint => 'Opcional, p.e. 42';

  @override
  String get llmSeedHelp =>
      'Configurar esto hace que la salida sea reproducible.';

  @override
  String get llmInheritedCustomHelp =>
      'Los parámetros personalizados del proveedor se muestran aquí y se sincronizan cada vez que se abre esta página.';

  @override
  String get llmBooleanParamHelp =>
      'Los parámetros booleanos no necesitan un valor.';

  @override
  String get modelContextReq => 'Se requiere longitud de contexto.';

  @override
  String get modelContextPositive =>
      'La longitud del contexto debe ser un número entero positivo.';

  @override
  String modelParamNameInvalid(String name) {
    return 'Nombre de parámetro no válido (los segmentos separados por puntos no pueden estar vacíos): $name';
  }

  @override
  String modelParamFinite(String name, String valueLabel, String value) {
    return 'El parámetro \"$name\" $valueLabel debe ser un número finito: $value';
  }

  @override
  String get modelReasoningIncomplete =>
      'Complete la alternancia de razonamiento antes de habilitar otros parámetros de razonamiento.';

  @override
  String get modelReasoningOptionsRequired =>
      'Agregue al menos un valor de opción al parámetro de razonamiento.';

  @override
  String modelReasoningError(String error) {
    return 'Error de parámetro de razonamiento: $error';
  }

  @override
  String modelReasoningDuplicate(String name) {
    return 'Parámetro de razonamiento duplicado: $name';
  }

  @override
  String modelReasoningCustomDuplicate(String name) {
    return 'El razonamiento y los parámetros personalizados comparten el nombre: $name';
  }

  @override
  String get modelSeedRequired =>
      'La semilla aleatoria está habilitada pero vacía.';

  @override
  String get ocrParamsTitle => 'Parámetros de OCR';

  @override
  String get ocrParamsHelp =>
      'Utiliza el formato de finalización de chat de visión compatible con OpenAI. Los parámetros siguientes son opcionales; Los parámetros no configurados o deshabilitados no se envían. Agregue los parámetros específicos del proveedor a continuación si su API lo admite.';

  @override
  String get ocrRequestSizeOverride => 'Solicitar anulación de tamaño JSON';

  @override
  String get ocrInheritProvider =>
      'Déjelo vacío para heredar la configuración del proveedor';

  @override
  String get ocrBudgetDefault =>
      'Cuando está vacío, hereda la configuración del proveedor; si el proveedor no tiene valor, el valor predeterminado es 20 MiB.';

  @override
  String ocrBudgetValue(String size) {
    return 'Cuando está vacío, hereda la configuración del proveedor ($size MiB); si el proveedor no tiene valor, el valor predeterminado es 20 MiB.';
  }

  @override
  String audioTrimDirection(String direction, String seconds) {
    return 'Revestimiento $direction ${seconds}s';
  }

  @override
  String audioTrimBeginning(String seconds) {
    return 'Recorte los primeros $seconds';
  }

  @override
  String get audioTrimNone => 'No recortar audio';

  @override
  String get trimNameLabel => 'Nombre del método de recorte *';

  @override
  String get trimNameHint => 'p.ej. recorte de silencio';

  @override
  String get trimDurationLabel => 'Duración del recorte (segundos) *';

  @override
  String get trimDurationHint => 'p.ej. 0.123';

  @override
  String get trimNameAndDurationRequired =>
      'El nombre y la duración son obligatorios.';

  @override
  String get trimDurationInvalid => 'Introduzca una duración positiva válida.';

  @override
  String get testAudioHostMissing => 'El host no está configurado.';

  @override
  String get testAudioKeyMissing => 'La clave no está configurada.';

  @override
  String testAudioContentTypeError(String contentType) {
    return 'El tipo de contenido de respuesta es $contentType, no audio.';
  }

  @override
  String get testAudioEmpty => 'El servidor devolvió datos de audio vacíos.';

  @override
  String testAudioTimeoutConnection(String details) {
    return 'Se agotó el tiempo de conexión. Comprueba tu red. $details';
  }

  @override
  String testAudioTimeoutReceive(String details) {
    return 'Recibir tiempo de espera agotado; el servidor respondió demasiado lento. $details';
  }

  @override
  String testAudioRequestCancelled(String details) {
    return 'Solicitud cancelada. $details';
  }

  @override
  String testAudioNetworkError(String message) {
    return 'Error de red: $message';
  }

  @override
  String get testAudioNoBody => 'Sin cuerpo de respuesta';

  @override
  String testAudioCorsHelp(String details) {
    return 'No se puede conectar al servidor. En la web, esto puede deberse a CORS o a una URL de API incorrecta. Verifique la URL de la API del proveedor y si el servidor permite solicitudes de origen cruzado. $details';
  }

  @override
  String get trimModelNameHint =>
      'Un nombre descriptivo para visualización e identificación, p. \"GPT-4o MiniTTS\". Utilice diferentes nombres para distinguir modelos del mismo proveedor.';

  @override
  String get trimModelIdHelp =>
      'Identificador único utilizado en llamadas API, p. \"gpt-4o-mini-tts\". Debe coincidir con el ID del modelo proporcionado por el proveedor.';

  @override
  String get ttsVoiceRangeTitle => 'rango de volumen';

  @override
  String get ttsMinVolume => 'Volumen mínimo';

  @override
  String get ttsMaxVolume => 'Volumen máximo';

  @override
  String get ttsSpeedRangeTitle => 'Rango de velocidad';

  @override
  String get ttsMinSpeed => 'Velocidad mínima';

  @override
  String get ttsMaxSpeed => 'Velocidad máxima';

  @override
  String get ttsMaxAudioLength => 'Duración máxima de audio por solicitud *';

  @override
  String get ttsAudioLengthHint => 'p.ej. 1000';

  @override
  String get ttsNoVoices => 'Sin voces. Toque para editar.';

  @override
  String get ttsInstructionSupported =>
      'El modelo admite el parámetro de instrucción.';

  @override
  String get ttsInstructionHelp =>
      'Cuando están habilitadas, las solicitudes TTS pueden incluir instrucciones sobre tono, emoción, velocidad de habla y más.';

  @override
  String get ttsStreamSupported => 'El modelo admite salida de streaming';

  @override
  String get ttsStreamHelp =>
      'Habilita este modelo para escenarios de streaming. Confirme que el modelo admita la transmisión antes de habilitarla.';

  @override
  String modelParamBooleanExpected(String name, String value) {
    return 'El parámetro “$name” debe ser verdadero o falso: $value';
  }

  @override
  String get ttsMaxAudioLengthRequired =>
      'Se requiere una duración máxima de audio por solicitud; introduzca un número entero positivo.';

  @override
  String get asrLanguageExample => 'p.ej. zh, en, ja';

  @override
  String get llmReasoningFullHelp =>
      'La palanca de razonamiento controla si se envía el razonamiento y le permite definir el nombre del parámetro y los valores de activación/desactivación. Hay un parámetro de esfuerzo de razonamiento. Seleccione valores y arrástrelos para reordenarlos; Los valores seleccionados aparecen en el panel de razonamiento del chat. Agregue otros parámetros de razonamiento a continuación. Los nombres de los parámetros admiten notación de puntos como think.type, que se convierte en un objeto JSON anidado. Los parámetros de razonamiento del proveedor se sincronizan cuando se abre esta página. Los interruptores aquí controlan los parámetros del modelo; la palanca de razonamiento del chat está separada.';

  @override
  String get llmTemperatureHelp =>
      'Controla la aleatoriedad de la salida; Los valores más altos son más creativos.';

  @override
  String get llmBooleanValueHelp =>
      'Los parámetros booleanos no necesitan un valor.';

  @override
  String get reasoningDisableEffort =>
      'Deshabilitar el esfuerzo de razonamiento';

  @override
  String get reasoningEnableEffort => 'Habilitar el esfuerzo de razonamiento';

  @override
  String get ocrJsonSizePositive =>
      'El tamaño JSON de la solicitud debe ser un valor MiB positivo.';

  @override
  String ttsRangePair(String kind) {
    return 'Ingrese el $kind mínimo y máximo, o déjelos vacíos.';
  }

  @override
  String get ttsEditTrimTitle => 'Editar recorte personalizado';

  @override
  String ttsVoicesCount(String count) {
    return 'Voces ($count)';
  }

  @override
  String ttsRequestFormatExample(String syntax) {
    return 'Generado en el formato de solicitud: $syntax';
  }

  @override
  String get mcpServerNameRequired => 'Introduzca un nombre de servidor MCP.';

  @override
  String get mcpStdioCommandRequired => 'El modo stdio requiere un comando.';

  @override
  String get mcpSseUrlRequired => 'El modo SSE requiere una URL.';

  @override
  String get mcpEditServerTitle => 'Editar servidor MCP';

  @override
  String get mcpCreateServerTitle => 'Nuevo servidor MCP';

  @override
  String get mcpUnsavedChangesTitle => 'Cambios no guardados';

  @override
  String get mcpUnsavedChangesConfirm =>
      'Tienes cambios sin guardar. ¿Descartarlos?';

  @override
  String get mcpTransportType => 'Tipo de transporte';

  @override
  String get mcpServerName => 'Nombre del servidor';

  @override
  String get mcpServerNameHint => 'Introduzca un nombre de servidor MCP';

  @override
  String get mcpCommand => 'Dominio';

  @override
  String get mcpCommandExample => 'Ejemplo: npx';

  @override
  String get mcpArguments => 'Argumentos';

  @override
  String get mcpArgumentsHint =>
      'Separe los argumentos con comas, por ejemplo: -y, @modelcontextprotocol/server-filesystem, /tmp';

  @override
  String get mcpSseUrlExample => 'Ejemplo: http://localhost:3001/sse';

  @override
  String get mcpApiKey => 'clave API';

  @override
  String get mcpApiKeyHint => 'Ingrese una clave API (opcional)';

  @override
  String get mcpShowKey => 'Mostrar clave';

  @override
  String get mcpHideKey => 'Ocultar clave';

  @override
  String get mcpDescriptionHint =>
      'Ingrese una descripción para este servidor MCP (opcional)';

  @override
  String get mcpStdioDescription =>
      'stdio inicia un proceso secundario local como servidor MCP y se comunica a través de entrada/salida estándar. Recomendado para herramientas locales.';

  @override
  String get mcpSseDescription =>
      'SSE se conecta a un servidor MCP remoto a través de HTTP SSE. Recomendado para servicios remotos.';

  @override
  String get mcpLocalStdio => 'Local (esdio)';

  @override
  String get mcpRemoteSse => 'Remoto (SSE)';

  @override
  String get mcpSaving => 'Ahorro…';

  @override
  String get providerTestSafetyNote =>
      'Esta prueba envía una solicitud real al servicio seleccionado. MCP solo llama al método de lista/herramientas de solo lectura; HTTP y la búsqueda web ejecutan una consulta. Todo lee la lista de forma predeterminada; Para proteger los datos actuales, omita el parámetro todos o configúrelo en nulo.';

  @override
  String get providerDeleteConfigTitle => 'Eliminar configuración';

  @override
  String get providerDeleteConfigConfirm =>
      '¿Eliminar esta configuración de proveedor y todos sus modelos?';

  @override
  String get providerCreateGroup => 'Nuevo grupo';

  @override
  String get providerEditGroup => 'Editar grupo';

  @override
  String get providerGroupName => 'Nombre del grupo';

  @override
  String get providerGroupNameExists => 'Ya existe un grupo con este nombre.';

  @override
  String get providerDeleteGroup => 'Eliminar grupo';

  @override
  String providerDeleteGroupConfirm(String groupName) {
    return 'Al eliminar \"$groupName\", sus configuraciones se moverán a \"Otros servicios MCP\".';
  }

  @override
  String get providerMoveToGroup => 'Mover al grupo';

  @override
  String get providerUnnamed => '(Sin nombre)';

  @override
  String get providerHttpSearch => 'búsqueda HTTP';

  @override
  String providerHttpToolSubtitle(String url) {
    return 'Herramienta HTTP: $url';
  }

  @override
  String providerLocalStdioSubtitle(String command) {
    return 'Local (diodo estándar): $command';
  }

  @override
  String providerRemoteSseSubtitle(String url) {
    return 'Remoto (SSE): $url';
  }

  @override
  String get providerServices => 'Configuraciones de servicio';

  @override
  String get providerServicesDescription =>
      'Administre conexiones remotas, stdio local y búsqueda HTTP por grupo';

  @override
  String get providerCreateGroupAction => 'Nuevo grupo';

  @override
  String get providerGroupEmpty =>
      'Este grupo no tiene configuraciones. Seleccione \"Agregar\" para agregar un elemento.';

  @override
  String get providerBuiltinTools => 'Herramientas integradas';

  @override
  String get providerBuiltinToolsDescription =>
      'Interfaces de herramientas locales proporcionadas por Stroom. La búsqueda web aparece en su grupo de servicios.';

  @override
  String get providerBuiltinToolInterface =>
      'Interfaz de herramienta incorporada';

  @override
  String get providerViewInterface => 'Ver interfaz';

  @override
  String get providerConfigTitle => 'Configuración';

  @override
  String get providerNotFound => 'Proveedor no encontrado';

  @override
  String get providerConfigurationHeading => 'Configuración del proveedor';

  @override
  String get providerBuiltinWebSearchEmpty =>
      'La búsqueda web integrada es compatible con Google, Bing y Baidu. El nombre de su herramienta modelo es web_search.';

  @override
  String get providerNoConfigsAdd =>
      'Aún no hay configuraciones de proveedor. Seleccione \"Agregar\" para crear uno.';

  @override
  String get providerNoHost => '(Anfitrión no configurado)';

  @override
  String get providerServicesAndTools => 'Servicios y herramientas';

  @override
  String get providerManageServicesDescription =>
      'Administre servidores MCP, búsqueda HTTP y herramientas integradas de Stroom.';

  @override
  String get providerNoServices => 'Aún no hay configuraciones de servicio';

  @override
  String get providerAddServiceDescription =>
      'Agregue un servicio MCP o una interfaz de búsqueda HTTP para usarlo en asistentes.';

  @override
  String get providerAddService => 'Agregar servicio';

  @override
  String get providerBuiltinBadge => 'Incorporado';

  @override
  String get providerBuiltinTtsName => 'Proveedor de TTS';

  @override
  String get providerBuiltinLlmName => 'Proveedor de Maestría en Derecho';

  @override
  String get providerBuiltinOcrName => 'Proveedor de OCR';

  @override
  String get providerBuiltinAsrName => 'Proveedor de reconocimiento de voz';

  @override
  String get providerBuiltinMcpName => 'Proveedor MCP';

  @override
  String get providerBuiltinSearchGroupName => 'Buscar';

  @override
  String get providerBuiltinMcpServicesGroupName => 'Otros servicios de MCP';

  @override
  String get providerConnectivityTest => 'Prueba de conectividad';

  @override
  String get providerMoveGroupTooltip => 'Mover al grupo';

  @override
  String get providerDeleteTooltip => 'Eliminar configuración';

  @override
  String providerGroupItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# elementos',
      one: '# elemento',
      zero: 'No hay elementos',
    );
    return '$_temp0';
  }

  @override
  String get providerGroupActions => 'Acciones grupales';

  @override
  String get providerEditGroupAction => 'Editar grupo';

  @override
  String get providerDeleteGroupAction => 'Eliminar grupo';

  @override
  String get providerAddItem => 'Agregar artículo';

  @override
  String get providerMcpMasterLabel => 'Servidores MCP';

  @override
  String get providerMcpMasterDescription =>
      'Controla si los servidores MCP y las herramientas de búsqueda integradas están disponibles en asistentes y chats.';

  @override
  String get providerEnabled => 'Activado';

  @override
  String get providerDisabled => 'Desactivado';

  @override
  String get providerEditSettings => 'Editar la configuración del proveedor';

  @override
  String get providerModelList => 'Modelos';

  @override
  String get providerNoModels => 'Aún no hay modelos';

  @override
  String get providerDeleteModel => 'Eliminar modelo';

  @override
  String get providerDeleteModelConfirm =>
      '¿Estás seguro de que deseas eliminar este modelo?';

  @override
  String get providerEditConfig => 'Editar configuración';

  @override
  String providerCreateNamedConfig(String entryName) {
    return 'Nueva configuración $entryName';
  }

  @override
  String get toolHttpSearchType => 'Tipo de conexión: búsqueda HTTP';

  @override
  String toolInterface(String name) {
    return 'Interfaz de herramienta: $name';
  }

  @override
  String get toolParameterDefinitions => 'Definiciones de parámetros';

  @override
  String get toolHttpAddress => 'URL de punto final HTTP';

  @override
  String get toolInvalidHttpUrl => 'Introduzca una URL HTTP o HTTPS válida.';

  @override
  String get toolBuiltinType =>
      'Tipo de conexión: herramienta incorporada Stroom';

  @override
  String get toolBuiltinEnableHelp =>
      'Habilite esta herramienta para un asistente en la configuración de herramientas predeterminada de ese asistente.';

  @override
  String get mcpSseUrlLabel => 'URL SSE';

  @override
  String get mcpUrlLabel => 'URL';

  @override
  String providerModelId(String modelId) {
    return 'ID del modelo: $modelId';
  }

  @override
  String get providerValueNotSet => '(No establecido)';

  @override
  String get providerApiKeyInputHint => 'Ingrese una clave API';

  @override
  String get providerSettingsTitle => 'Configuración del proveedor';

  @override
  String get providerBasicInfoTab => 'Información básica';

  @override
  String get providerParameterSettingsTab => 'Configuración de parámetros';

  @override
  String get providerOptionValuesReorderHelp =>
      'Valores de opciones (mantenga presionado el controlador para arrastrar y reordenar)';

  @override
  String providerOptionIndexLabel(String index) {
    return 'Opción $index';
  }

  @override
  String providerOptionExampleHint(String example) {
    return 'p.ej. $example';
  }

  @override
  String get providerDeleteOptionTooltip => 'Eliminar opción';

  @override
  String get providerAddOption => 'Agregar opción';

  @override
  String get providerAddCustomParam => 'Agregar parámetro';

  @override
  String get providerNoCustomParams => 'Aún no hay parámetros personalizados';

  @override
  String get providerParamNameLabel => 'Nombre del parámetro';

  @override
  String get providerParamDefaultValueLabel =>
      'Valor de parámetro predeterminado';

  @override
  String get providerBooleanParamNoValue =>
      'Los parámetros booleanos no necesitan un valor. El panel de chat proporciona un interruptor de encendido/apagado.';

  @override
  String get providerReasoningParamsHeading => 'Parámetros de razonamiento';

  @override
  String providerReasoningSettingsHelp(
    String parameterName,
    String jsonExample,
  ) {
    return 'La palanca de razonamiento activa o desactiva el razonamiento en el chat; usted elige el nombre del parámetro y los valores de activación/desactivación. Puede configurar un parámetro de esfuerzo de razonamiento con un nombre obligatorio y opciones opcionales. Si ingresa solo un nombre, la configuración del modelo puede proporcionar los valores. Utilice los botones siguientes para agregar otros parámetros de razonamiento. Los nombres de los parámetros admiten el anidamiento de puntos; por ejemplo, $parameterName se expande a $jsonExample.';
  }

  @override
  String get providerAddReasoningParam => 'Agregar parámetro de razonamiento';

  @override
  String get providerAddReasoningToggle => 'Agregar palanca de razonamiento';

  @override
  String get providerReasoningToggle => 'alternar razonamiento';

  @override
  String get providerDeleteReasoningToggle =>
      'Eliminar palanca de razonamiento';

  @override
  String providerParamNameHint(String examples) {
    return 'p.ej. $examples';
  }

  @override
  String get providerReasoningBooleanHelp =>
      'Los parámetros booleanos no necesitan un valor. El panel de chat proporciona un interruptor de encendido/apagado.';

  @override
  String get providerToggleOnValueLabel => 'En valor';

  @override
  String get providerToggleOffValueLabel => 'Valor apagado';

  @override
  String providerReasoningToggleSummary(String onValue, String offValue) {
    return 'Cuando el razonamiento esté activado, envíe “$onValue”; cuando esté apagado, envíe “$offValue”.';
  }

  @override
  String get providerAddReasoningEffort => 'Añadir esfuerzo de razonamiento';

  @override
  String get providerDeleteReasoningEffort =>
      'Eliminar parámetro de esfuerzo de razonamiento';

  @override
  String get providerReasoningEffortLockedHint =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get providerJsonValueLabel => 'valor JSON';

  @override
  String get providerReasoningOptionsHelp =>
      'Valores de opción (opcional; si solo se ingresa el nombre del parámetro, la configuración del modelo proporciona el valor). Mantenga presionada la manija para arrastrar y reordenar.';

  @override
  String get providerParamNameNestedLabel =>
      'Nombre del parámetro (admite anidamiento de puntos)';

  @override
  String get providerToggleEffortPrerequisite =>
      'Complete la alternancia de razonamiento antes de configurar el esfuerzo de razonamiento.';

  @override
  String get providerToggleRequiredHint =>
      'Primero complete el cambio de razonamiento.';

  @override
  String get providerDeleteCustomParam => 'Eliminar parámetro';

  @override
  String get modelSaveSuccess => 'Modelo guardado';

  @override
  String get modelSaving => 'Ahorro…';

  @override
  String modelOriginalError(String error) {
    return 'Error original: $error';
  }

  @override
  String get paramTypeStringLabel => 'Cadena';

  @override
  String get paramTypeNumberLabel => 'Número';

  @override
  String get paramTypeBooleanLabel => 'Booleano';

  @override
  String get paramTypeJsonLabel => 'JSON';

  @override
  String ocrConfigUnsupportedParamType(String type) {
    return 'Tipo no compatible: $type';
  }

  @override
  String ocrConfigUnsupportedParamSaveError(String name, String type) {
    return 'El parámetro “$name” utiliza el tipo “$type” no admitido. Reemplácelo con un tipo compatible o elimine el parámetro antes de guardar.';
  }

  @override
  String get paramTypeStringHint => 'p.ej. alegre';

  @override
  String get paramTypeNumberHint => 'p.ej. 0,8';

  @override
  String get paramTypeBooleanHint => 'p.ej. verdadero';

  @override
  String get paramTypeJsonHint => 'p.ej.';

  @override
  String get ankiPageTitle => 'Tarjetas didácticas de Anki';

  @override
  String get ankiStatsTooltip => 'Estadísticas del estudio';

  @override
  String get ankiBrowseCardsTooltip => 'Explorar tarjetas';

  @override
  String get ankiStatsTotalCards => 'Tarjetas totales';

  @override
  String get ankiStatsNewCards => 'Nuevas cartas';

  @override
  String get ankiStatsLearning => 'Aprendiendo';

  @override
  String get ankiStatsDueForReview => 'Debido a revisión';

  @override
  String get ankiStatsReviewHistory => 'Revisar el historial';

  @override
  String get ankiStatsLearningProgress => 'Progreso del estudio';

  @override
  String get ankiStatsReviewRate => 'Tasa de revisión';

  @override
  String get ankiBrowserSearchHint => 'Buscar tarjetas...';

  @override
  String get ankiBrowserEmpty => 'sin tarjetas';

  @override
  String get ankiSyncTooltip => 'Sincronización AnkiWeb';

  @override
  String get ankiNewDeckTooltip => 'Nueva baraja';

  @override
  String ankiDeckLoadError(String error) {
    return 'No se pudieron cargar las plataformas: $error';
  }

  @override
  String get ankiEmptyDecksTitle => 'Aún no hay mazos';

  @override
  String get ankiEmptyDecksDescription =>
      'Crea un mazo para empezar a estudiar';

  @override
  String get ankiNewDeckTitle => 'Nueva baraja';

  @override
  String get ankiDeckNameHint => 'Nombre de la plataforma';

  @override
  String get ankiCreateDeck => 'Crear';

  @override
  String get ankiRenameDeck => 'Cambiar nombre de mazo';

  @override
  String get ankiConfirm => 'DE ACUERDO';

  @override
  String get ankiDeleteDeckTitle => 'Eliminar mazo';

  @override
  String ankiDeleteDeckConfirmation(String deckName) {
    return '¿Eliminar “$deckName” y todas sus tarjetas?';
  }

  @override
  String get ankiAddCardTitle => 'Agregar tarjeta';

  @override
  String get ankiNoteTypeLabel => 'tipo de nota';

  @override
  String ankiClozeTextHint(String clozeSyntax) {
    return 'Texto (marcar eliminaciones con $clozeSyntax)';
  }

  @override
  String get ankiFrontQuestionHint => 'Frente (pregunta)';

  @override
  String get ankiBackExtraLabel => 'Atrás/extra';

  @override
  String get ankiTagsLabel => 'Etiquetas (separadas por espacios)';

  @override
  String get ankiTagsHint => 'Ejemplo: física matemática';

  @override
  String get ankiAdd => 'Agregar';

  @override
  String get ankiStatNew => 'Nuevo';

  @override
  String get ankiStatLearning => 'Aprendiendo';

  @override
  String get ankiStatReview => 'Revisar';

  @override
  String get ankiAddCardAction => 'Agregar tarjeta';

  @override
  String get ankiRenameAction => 'Rebautizar';

  @override
  String get ankiDeleteAction => 'Borrar';

  @override
  String get ankiNoCardContent => 'Sin contenido de tarjeta';

  @override
  String get ankiStudy => 'Estudiar';

  @override
  String get ankiWhiteboardTooltip => 'Pizarra';

  @override
  String get ankiFrontLabel => 'Frente';

  @override
  String get ankiBackLabel => 'Atrás';

  @override
  String get ankiShowAnswer => 'Mostrar respuesta';

  @override
  String get ankiRatingAgain => 'De nuevo';

  @override
  String get ankiRatingHard => 'Duro';

  @override
  String get ankiRatingGood => 'Bien';

  @override
  String get ankiRatingEasy => 'Fácil';

  @override
  String get ankiNoCardsToStudy => 'No hay tarjetas para estudiar ahora mismo.';

  @override
  String get ankiNoCardsHint => 'Añade nuevas tarjetas o vuelve más tarde';

  @override
  String get ankiBack => 'Atrás';

  @override
  String get ankiSyncPageTitle => 'sincronización de anki';

  @override
  String get ankiSyncChooseMode => 'Elija un modo de sincronización';

  @override
  String get ankiSyncModeHelp =>
      'El estado de inicio de sesión se almacena por separado para cada servicio. El cambio de modos no fusiona ni sobrescribe datos.';

  @override
  String get ankiSyncSelfHostedMode => 'Servidor autohospedado';

  @override
  String get ankiSyncServerAddress => 'Dirección del servidor';

  @override
  String get ankiSyncServerHelp =>
      'Los servidores remotos autohospedados deben utilizar HTTPS; Se permite HTTP para direcciones locales. El servidor debe admitir Anki sync v10 y la verificación de certificados está habilitada de forma predeterminada.';

  @override
  String get ankiSyncCustomCaTitle => 'Certificado CA personalizado (opcional)';

  @override
  String get ankiSyncCustomCaHelp =>
      'Ingrese esto solo cuando el servidor use un certificado autofirmado';

  @override
  String get ankiSyncOfficialHelp =>
      'Utilice el servicio de sincronización oficial de AnkiWeb. Su contraseña se envía solo al iniciar sesión y no se almacena en Stroom.';

  @override
  String ankiSyncConnected(String service) {
    return 'Conectado a $service';
  }

  @override
  String ankiSyncNotConnected(String service) {
    return 'No conectado a $service';
  }

  @override
  String ankiSyncLoginForService(String service) {
    return 'Inicie sesión en $service';
  }

  @override
  String get ankiSyncCheckServerStatus => 'Verificar el estado del servidor';

  @override
  String get ankiSyncLogout => 'Finalizar la sesión';

  @override
  String get ankiSyncBothWays => 'Sincronización bidireccional';

  @override
  String get ankiSyncOverwriteServer =>
      'Reemplazar datos del servidor con datos locales';

  @override
  String get ankiSyncReplaceLocal =>
      'Reemplazar datos locales con datos del servidor';

  @override
  String get ankiSyncHelp =>
      'La sincronización bidireccional fusiona cambios incrementales de colección y transfiere archivos multimedia. Si la versión del esquema difiere, elija una carga o descarga completa. Una descarga completa fallida intentará restaurar la colección original y el directorio multimedia.';

  @override
  String get ankiSyncStatusRestored =>
      'Restableció la sesión de inicio de sesión guardada de forma segura';

  @override
  String get ankiSyncStatusReadSavedSessionFailed =>
      'No se pudo leer la sesión de inicio de sesión guardada. Por favor inicia sesión nuevamente.';

  @override
  String get ankiSyncInvalidServerUrl =>
      'La dirección del servidor debe ser una URL HTTPS. HTTP sólo se permite para una dirección de loopback local. No se permiten información de usuario ni parámetros de consulta.';

  @override
  String ankiSyncStatusSettingsNotSaved(String error) {
    return 'Configuración no guardada: $error';
  }

  @override
  String get ankiSyncStatusServerAddressChanged =>
      'La dirección del servidor cambió. Por favor inicie sesión nuevamente para continuar.';

  @override
  String get ankiSyncStatusVerifyingLogin => 'Verificando inicio de sesión…';

  @override
  String get ankiSyncStatusLoginSuccess =>
      'Inicie sesión exitosamente. Su contraseña no fue guardada; la clave de sincronización fue cifrada y guardada.';

  @override
  String get ankiSyncLoginSuccessPromptTitle => 'Inicio de sesión exitoso';

  @override
  String get ankiSyncLoginSuccessPromptMessage =>
      '¿Desea sincronizar su colección ahora?';

  @override
  String get ankiSyncLoginSuccessPromptSync => 'Sincronizar ahora';

  @override
  String get ankiSyncLoginSuccessPromptLater => 'Continuar';

  @override
  String get ankiSyncStatusLoginSuccessNoSave =>
      'Inicie sesión correctamente, pero la clave de sincronización no se pudo almacenar de forma segura. Deberá iniciar sesión nuevamente después de cerrar esta página.';

  @override
  String ankiSyncStatusLoginFailed(String error) {
    return 'Error al iniciar sesión: $error';
  }

  @override
  String get ankiSyncLoginAnkiWeb => 'Inicie sesión en AnkiWeb';

  @override
  String get ankiSyncLoginSelfHosted =>
      'Inicie sesión en el servidor autohospedado';

  @override
  String get ankiSyncEmailOrUsername => 'Correo electrónico/nombre de usuario';

  @override
  String get ankiSyncEmailOrUsernameRequired =>
      'Introduzca un correo electrónico o nombre de usuario';

  @override
  String get ankiSyncPassword => 'Contraseña';

  @override
  String get ankiSyncPasswordRequired => 'Introduce una contraseña';

  @override
  String get ankiSyncLogin => 'Acceso';

  @override
  String get ankiSyncStatusPreparingServerSettings =>
      'Preparando la configuración del servidor…';

  @override
  String get ankiSyncStatusReadingCollection =>
      'Leyendo el estado de la recopilación del servidor...';

  @override
  String get ankiSyncStatusConnectedCollectionEmpty =>
      'Conectado. La colección del servidor está vacía.';

  @override
  String get ankiSyncStatusConnectedStatusRead =>
      'Conectado. Se leyó el estado del servidor.';

  @override
  String get ankiSyncStatusUpgradeClient =>
      'Este servidor requiere un cliente de sincronización más nuevo.';

  @override
  String ankiSyncStatusCheckFailed(String error) {
    return 'Error en la verificación de estado: $error';
  }

  @override
  String get ankiSyncStatusPreparingUpload =>
      'Preparando la configuración de carga...';

  @override
  String get ankiSyncOverwriteServerConfirmTitle =>
      '¿Reemplazar la colección del servidor por la local?';

  @override
  String get ankiSyncOverwriteServerConfirmMessage =>
      'La colección del servidor será reemplazada completamente con datos locales. Stroom primero mantendrá una copia de seguridad de la base de datos local.\n\nLos archivos multimedia seguirán estando sincronizados en ambas direcciones según la lista de medios del servidor.';

  @override
  String get ankiSyncOverwriteServerAction =>
      'Reemplazar la colección del servidor';

  @override
  String get ankiSyncStatusBackingUpUploading =>
      'Copia de seguridad y carga de la colección...';

  @override
  String ankiSyncStatusUploadComplete(
    int uploaded,
    int downloaded,
    int deleted,
    String backup,
  ) {
    return 'El servidor aceptó la recogida local. Sincronización de medios completada: archivos $uploaded cargados, $downloaded descargados, $deleted eliminado.$backup Verifique el estado del servidor nuevamente.';
  }

  @override
  String ankiSyncStatusBackupPath(String path) {
    return 'Copia de seguridad local: $path';
  }

  @override
  String get ankiSyncStatusMediaSyncIncomplete =>
      'Se reemplazó la colección del servidor, pero la sincronización de medios no finalizó:';

  @override
  String get ankiSyncStatusUploadFailed => 'La carga falló:';

  @override
  String get ankiSyncStatusPreparingDownload =>
      'Preparando la configuración de descarga…';

  @override
  String get ankiSyncReplaceLocalConfirmTitle =>
      '¿Reemplazar la colección local con la del servidor?';

  @override
  String get ankiSyncReplaceLocalConfirmMessage =>
      'La colección local será reemplazada por datos del servidor. Stroom primero mantendrá una copia de seguridad de la base de datos local.\n\nLos medios del servidor reemplazarán los medios locales y se descargarán los archivos faltantes. Si algún paso falla o la aplicación se cierra en el medio, Stroom restaurará la colección y los medios locales antes de abrir las plataformas la próxima vez.';

  @override
  String get ankiSyncReplaceLocalAction => 'Reemplazar datos locales';

  @override
  String get ankiSyncStatusDownloadingValidating =>
      'Descargando y validando colección…';

  @override
  String ankiSyncStatusDownloadComplete(
    int downloaded,
    int uploaded,
    int deleted,
    String backup,
  ) {
    return 'La colección local fue reemplazada y pasó la verificación de SQLite. Sincronización de medios completada: archivos $downloaded descargados, $uploaded cargados, $deleted eliminado.$backup Verifique el estado del servidor nuevamente.';
  }

  @override
  String ankiSyncStatusDownloadFailed(String error) {
    return 'Descarga fallida: $error';
  }

  @override
  String get ankiSyncStatusPreparingSync => 'Preparando sincronización…';

  @override
  String get ankiSyncStatusMergingChanges =>
      'Fusionando cambios de colección...';

  @override
  String get ankiSyncStatusMergeCompleteSyncMedia =>
      'Los cambios de colección se fusionaron. Sincronizando archivos multimedia…';

  @override
  String ankiSyncStatusChangedNotes(int notes, int cards, int reviews) {
    return 'Notas $notes, tarjetas $cards y registros de revisión $reviews agregados o actualizados';
  }

  @override
  String get ankiSyncStatusNoCollectionChanges =>
      'No hay cambios de colección para fusionar';

  @override
  String ankiSyncStatusTwoWayComplete(
    String collection,
    int uploaded,
    int downloaded,
    int deleted,
  ) {
    return 'Sincronización bidireccional completa: $collection; medios cargados $uploaded, descargados $downloaded, eliminados $deleted.';
  }

  @override
  String get ankiSyncStatusCollectionMergedMediaIncomplete =>
      'Los cambios de colección se fusionaron, pero la sincronización de medios no finalizó:';

  @override
  String get ankiSyncStatusSyncIncomplete => 'La sincronización no finalizó:';

  @override
  String get ankiSyncStatusClearingLogin =>
      'Borrando la sesión de inicio de sesión…';

  @override
  String get ankiSyncStatusLoggedOut =>
      'Cerrado la sesión. La clave de sincronización se eliminó del almacenamiento seguro.';

  @override
  String get ankiSyncStatusClearLoginFailed =>
      'No se pudo borrar la sesión de inicio de sesión guardada';

  @override
  String get ankiSyncStatusOperationIncomplete =>
      'La operación no terminó. Verifique el almacenamiento seguro, la red y la dirección del servidor.';

  @override
  String get ankiSyncUnknown => 'Desconocido';

  @override
  String get ankiSyncServerCollectionEmpty =>
      'La colección de servidores está vacía';

  @override
  String get ankiSyncServerCollectionAvailable =>
      'La colección de servidores está disponible';

  @override
  String ankiSyncSchemaStatus(int schema, int usn, String modified) {
    return 'Versión del esquema $schema · USN $usn · Modificado $modified';
  }

  @override
  String get asrPageTitle => 'Transcripción de audio';

  @override
  String get clear => 'Limpiar';

  @override
  String get configure => 'Configurar';

  @override
  String get asrModel => 'Modelo de reconocimiento';

  @override
  String get reselectModel => 'Por favor seleccione un modelo nuevamente';

  @override
  String get selectAsrModel => 'Seleccione un modelo de reconocimiento';

  @override
  String get enterPublicAudioUrl => 'Introduce una URL de audio pública';

  @override
  String get recordingSelection => 'Grabaciones';

  @override
  String get audioFiles => 'Archivos de audio';

  @override
  String get noAudioSelected => 'No hay archivos de audio seleccionados';

  @override
  String get supportedAudioFormats =>
      'Admite formatos de audio comunes como WAV, MP3, M4A y OGG';

  @override
  String asrSelectedAudioCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos de audio seleccionados',
      one: '$count archivo de audio seleccionado',
      zero: 'No hay archivos de audio seleccionados',
    );
    return '$_temp0';
  }

  @override
  String asrSelectedAudioCountShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos de audio seleccionados',
      one: '$count archivo de audio seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get asrReselect => 'Seleccionar de nuevo';

  @override
  String get asrUrlLabel => 'URL | Enlace público';

  @override
  String get asrErrorDetails => 'Ver detalles del error';

  @override
  String get asrResultSaved => 'Resultado de la transcripción guardado';

  @override
  String get asrWorking => 'Transcribiendo…';

  @override
  String get asrStart => 'Iniciar transcripción';

  @override
  String get saveTo => 'Guardar en';

  @override
  String get rootFolder => 'Carpeta raíz';

  @override
  String get chooseSaveFolder => 'Elige una carpeta';

  @override
  String get linkAlreadyAdded => 'Este enlace ya está en la lista.';

  @override
  String get chooseAudioSource => 'Elige una fuente de audio';

  @override
  String get inAppRecordings => 'Grabaciones en la aplicación';

  @override
  String get chooseGeneratedRecordings => 'Elija entre grabaciones generadas';

  @override
  String get systemAudioFiles => 'Archivos de audio del sistema';

  @override
  String get chooseDeviceAudioFiles => 'Elija archivos de su dispositivo';

  @override
  String get cannotReadAudioFile => 'No se pudo leer el archivo de audio';

  @override
  String chooseAudioFileFailed(String details) {
    return 'No se pudo seleccionar el archivo de audio: $details';
  }

  @override
  String get chooseInAppRecording => 'Elija grabaciones en la aplicación';

  @override
  String get noRecordings => 'Sin grabaciones';

  @override
  String durationSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds segundos',
      one: '$seconds segundo',
    );
    return '$_temp0';
  }

  @override
  String get asrNeedsProvider =>
      'Configure primero un proveedor y un modelo de transcripción de audio en Configuración';

  @override
  String get asrModelUnavailable =>
      'El modelo de reconocimiento original no está disponible o no se puede verificar. Por favor seleccione un modelo nuevamente.';

  @override
  String get asrUrlProviderRemoveFiles =>
      'Este proveedor carga audio por URL. Elimine los archivos de audio locales y vuelva a intentarlo.';

  @override
  String get asrFileProviderRemoveUrls =>
      'Este proveedor carga archivos de audio y no admite la transcripción por enlace. Elimina enlaces e inténtalo de nuevo.';

  @override
  String asrTaskStartFailed(String details) {
    return 'No se pudo iniciar la tarea: $details';
  }

  @override
  String get asrInvalidUrl =>
      'URL no válida. Debe comenzar con http:// o https://';

  @override
  String get asrEnterAudioUrl => 'Introduce una URL de audio';

  @override
  String get asrUrlProviderHelp =>
      'Este proveedor carga audio por URL. Ingrese una URL de audio pública (http/https).';

  @override
  String get cancel => 'Cancelar';

  @override
  String get add => 'Agregar';

  @override
  String get ttsPageTitle => 'Audio';

  @override
  String ttsAudioImportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron $count archivos de audio',
      one: 'Se importó $count archivo de audio',
    );
    return '$_temp0';
  }

  @override
  String ttsImportFailed(String details) {
    return 'Error de importación: $details';
  }

  @override
  String get ttsFileReadFailed => 'No se pudieron leer los datos del archivo';

  @override
  String get ttsExportAudioFile => 'Exportar archivo de audio';

  @override
  String ttsExportedTo(String path) {
    return 'Exportado a: $path';
  }

  @override
  String ttsExportFailed(String details) {
    return 'Error al exportar: $details';
  }

  @override
  String get ttsConfirmRegenerate => 'Confirmar regeneración';

  @override
  String ttsRegenerateConfirmFile(String fileName) {
    return '¿Regenerar audio “$fileName”?';
  }

  @override
  String get ttsRegenerateOverwrite =>
      'El archivo de audio original será reemplazado después de la regeneración.';

  @override
  String get ttsRegenerate => 'regenerar audio';

  @override
  String ttsCopiedFailed(String details) {
    return 'No se pudo copiar: $details';
  }

  @override
  String get ttsChooseExportFolder => 'Elija la carpeta de exportación';

  @override
  String get ttsExportAudio => 'Exportar audio';

  @override
  String ttsExportedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se exportaron $count archivos',
      one: 'Se exportó $count archivo',
    );
    return '$_temp0';
  }

  @override
  String get ttsFolderExport => 'Exportar carpeta';

  @override
  String get ttsWebFolderExportHelp =>
      'Su navegador no puede elegir una carpeta de exportación. Se descargará un archivo ZIP con la estructura de carpetas conservada.';

  @override
  String get ttsDownloadZip => 'Descargar archivo ZIP';

  @override
  String get ttsExportAudioFolder => 'Exportar carpeta de audio';

  @override
  String get ttsRecord => 'Registro';

  @override
  String get ttsImport => 'Importar';

  @override
  String get ttsPlay => 'Jugar';

  @override
  String get ttsExportLocal => 'Exportar al dispositivo';

  @override
  String get ttsRegenerateQuestion => 'Regenerado';

  @override
  String get ttsNeedsProvider =>
      'Configure primero un proveedor y un modelo de síntesis de voz en Configuración';

  @override
  String get ttsAddedToTasks =>
      'Agregado a la lista de tareas. Generando en segundo plano…';

  @override
  String get ttsCreateTitle => 'Síntesis del habla';

  @override
  String get ttsOriginalTitle => 'Título de la grabación';

  @override
  String get ttsUseOriginalTitle => 'Usar título original';

  @override
  String get ttsAudioFileNameHint =>
      'Nombre del archivo de audio guardado (opcional)';

  @override
  String get ttsTextToConvert => 'Texto para convertir';

  @override
  String get ttsSpeechContent => 'Contenido del discurso';

  @override
  String get ttsTextHint => 'Ingrese el texto para convertirlo a voz...';

  @override
  String get ttsFullscreenEdit => 'Editar en pantalla completa';

  @override
  String ttsTextLimitWarning(int limit) {
    return 'El texto excede el límite (máximo de caracteres $limit)';
  }

  @override
  String get ttsSynthesisConfig => 'Configuración de síntesis';

  @override
  String get ttsVoiceAndSoundHelp => 'Ajustar la voz y el sonido.';

  @override
  String get ttsProviderSettingsLead => 'en';

  @override
  String get ttsProviderSettings => 'Configuración del proveedor TTS';

  @override
  String get ttsProviderSettingsTail => 'para configurar más parámetros';

  @override
  String get ttsEditText => 'Editar texto';

  @override
  String get ttsClose => 'Cerrar';

  @override
  String get ttsVoice => 'Voz';

  @override
  String get ttsSelectVoice => 'Seleccione una voz';

  @override
  String get ttsSpeed => 'Velocidad';

  @override
  String get ttsNormal => 'Normal';

  @override
  String get ttsVolume => 'Volumen';

  @override
  String get ttsInstruction => 'Instrucción de estilo de habla.';

  @override
  String get ttsInstructionHint =>
      'Por ejemplo: Habla en un tono alegre y emocionado.';

  @override
  String get ttsCustomParams => 'Parámetros personalizados';

  @override
  String ttsDefaultValue(Object value) {
    return 'Valor predeterminado: $value';
  }

  @override
  String get ttsGenerateRecording => 'Generar grabación';

  @override
  String ttsSaveAs(String path, String name, String format) {
    return 'Guardar como: $path/$name.$format';
  }

  @override
  String get ttsChooseSaveFolder => 'Elige una carpeta';

  @override
  String get ttsFillTextError => 'Ingrese el texto para convertir';

  @override
  String get voiceBatchTitle => 'Añadir voces de forma masiva';

  @override
  String get voiceBatchConfirm => 'Agregar voces seleccionadas';

  @override
  String get voiceBatchSeparator => 'Separador:';

  @override
  String get voiceBatchCustomSeparatorHint =>
      'Introduzca un separador personalizado';

  @override
  String get voiceBatchFieldOrder => 'Orden de campo:';

  @override
  String get voiceBatchNameThenId => '1º = nombre, 2º = DNI';

  @override
  String get voiceBatchIdThenName => '1º = DNI, 2º = nombre';

  @override
  String voiceBatchColumnChoice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se detectaron $count columnas. Elija la columna inicial para el nombre/ID:',
      one:
          'Se detectó $count columna. Elija la columna inicial para el nombre/ID:',
    );
    return '$_temp0';
  }

  @override
  String voiceBatchColumn(int index, String sample) {
    return 'Columna $index: $sample';
  }

  @override
  String get voiceBatchSingleColumn =>
      'Se detectó una columna. Todos los valores se utilizarán como ID (nombre = ID).';

  @override
  String get voiceBatchInputHint =>
      'Separe el nombre y el ID con tabulador, coma, punto y coma o barras verticales (un par por línea)';

  @override
  String get voiceBatchNoPreview => 'Nada que previsualizar';

  @override
  String get voiceName => 'Nombre de voz';

  @override
  String get voiceId => 'Identificación de voz';

  @override
  String get status => 'Estado';

  @override
  String get voiceNew => '✅ Nuevo';

  @override
  String get voiceIdExists => '⚠️ La identificación ya existe';

  @override
  String voiceFormatError(String details) {
    return '❌ Error de formato$details';
  }

  @override
  String voiceDuplicateIds(int count, String ids) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ID duplicados encontrados: $ids',
      one: '$count ID duplicado encontrado: $ids',
    );
    return '$_temp0';
  }

  @override
  String get voiceInsufficientColumnData =>
      'No hay suficientes datos en las columnas seleccionadas';

  @override
  String get voiceCustomSeparator => 'Costumbre…';

  @override
  String get voiceCommaSeparator => 'Coma (,)';

  @override
  String get voiceSemicolonSeparator => 'Punto y coma (;)';

  @override
  String get voicePipeSeparator => 'Barra vertical (|)';

  @override
  String get voiceTabSeparator => 'Pestaña';

  @override
  String get voiceEditorTitle => 'Editar voces';

  @override
  String get save => 'Guardar';

  @override
  String get voiceAddRow => 'Agregar fila';

  @override
  String get voiceBatchAdd => 'Añadir en masa';

  @override
  String get voiceNoneAdd => 'Aún no hay voces. Agregue uno para comenzar.';

  @override
  String get delete => 'Borrar';

  @override
  String get voiceDuplicateResolution =>
      'Las siguientes identificaciones de voz están duplicadas. Elige cómo manejar cada uno:';

  @override
  String get update => 'Actualizar';

  @override
  String get skip => 'Saltar';

  @override
  String voiceDuplicatesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count duplicados',
      one: 'Queda $count duplicado',
    );
    return '$_temp0';
  }

  @override
  String get continueEditing => 'Continuar editando';

  @override
  String get asrRetryIncomplete =>
      'El audio reintentado está incompleto. Borre la lista y seleccione todo el audio nuevamente.';

  @override
  String asrRetryAudioUnreadable(String details) {
    return 'No se pudieron leer los datos de audio al reintentar. Seleccione el audio nuevamente: $details';
  }

  @override
  String get asrLegacyRetryUnavailable =>
      'El audio de reintento heredado no está disponible. Seleccione el audio nuevamente.';

  @override
  String get asrRetryDataUnreadable =>
      'No se pudieron leer los datos del reintento. Seleccione el audio nuevamente.';

  @override
  String get ttsSynthesisModel => 'Modelo de síntesis';

  @override
  String get asrRetryUnavailable =>
      'Reintentar audio no está disponible. Seleccione el audio nuevamente.';

  @override
  String get chatRequest => 'Pedido';

  @override
  String get chatResponse => 'Respuesta';

  @override
  String get chatNoErrorDetails => 'No hay detalles disponibles';

  @override
  String get ttsInstructionDescription =>
      'Describir tono, emoción, velocidad, acento y otras cualidades en lenguaje natural. El modelo ajusta la voz sintetizada en consecuencia.';

  @override
  String get audioPlayerSourceTextSource => 'Elige el texto fuente';

  @override
  String get audioPlayerChooseInAppText => 'Elija en el texto de la aplicación';

  @override
  String get audioPlayerChooseSavedTextSubtitle =>
      'Elija un archivo de texto guardado desde la aplicación';

  @override
  String get audioPlayerChooseSystemText =>
      'Elija el archivo de texto del sistema';

  @override
  String get audioPlayerChooseDeviceTextSubtitle =>
      'Elija un archivo de texto del almacenamiento del dispositivo';

  @override
  String get audioPlayerSelectInAppText => 'Elija en el texto de la aplicación';

  @override
  String get audioPlayerNoTextFiles => 'Aún no hay archivos de texto';

  @override
  String audioPlayerCharacterCount(int count) {
    return '$count caracteres';
  }

  @override
  String audioPlayerSelectTextFailure(String error) {
    return 'No se pudo seleccionar el texto: $error';
  }

  @override
  String get audioPlayerCannotReadTextFile =>
      'No se puede leer el archivo de texto';

  @override
  String audioPlayerUploadTextFailure(String error) {
    return 'No se pudo cargar el texto fuente: $error';
  }

  @override
  String get audioPlayerTextContentEmpty => 'El texto está vacío.';

  @override
  String audioPlayerSaveTextFailure(String error) {
    return 'No se pudo guardar el texto fuente: $error';
  }

  @override
  String get audioPlayerSourceTextUploaded => 'Texto fuente subido';

  @override
  String get audioPlayerSourceTextUpdated => 'Texto fuente actualizado';

  @override
  String get audioPlayerConfigureTtsProvider =>
      'Configure primero un proveedor TTS';

  @override
  String get audioPlayerNoStreamingModels =>
      'Ningún modelo admite reproducción en streaming';

  @override
  String get audioPlayerSelectStreamingModel =>
      'Seleccione un modelo de reproducción en streaming';

  @override
  String get audioPlayerProviderFallback => 'Proveedor';

  @override
  String audioPlayerStartStreaming(String model) {
    return 'Iniciando la reproducción en streaming: $model';
  }

  @override
  String audioPlayerFileNotFound(String path) {
    return 'Archivo de audio no encontrado: $path';
  }

  @override
  String get audioPlayerUnableToLoadAudio =>
      'No se pueden cargar datos de audio';

  @override
  String get audioPlayerSourceText => 'Texto fuente';

  @override
  String get audioPlayerNoSourceText => '(Sin texto fuente)';

  @override
  String get audioPlayerUploadSourceText => 'Subir texto fuente';

  @override
  String get audioPlayerEditSourceText => 'Editar texto fuente';

  @override
  String get audioPlayerCompanionTextMissing =>
      'No se encontró ningún archivo de texto complementario';

  @override
  String get audioPlayerPlaySelection => 'Selección de juego';

  @override
  String get audioPlayerGenerateSelection => 'Generar selección';

  @override
  String get audioPlayerPlaying => 'Jugando...';

  @override
  String get audioPlayerPaused => 'En pausa';

  @override
  String get audioPlayerPlaybackSpeed => 'Velocidad de reproducción';

  @override
  String get audioPlayerFailed => 'Error de reproducción';

  @override
  String get audioPlayerRetry => 'Rever';

  @override
  String get audioPlayerLoading => 'Cargando audio...';

  @override
  String get audioPlayerClose => 'Cerrar';

  @override
  String get audioRecordingBrowserUnsupportedShort =>
      'La grabación no es compatible con el navegador. Utilice la versión de la aplicación.';

  @override
  String get audioRecordingMicrophonePermissionRequired =>
      'Se requiere permiso de micrófono para grabar.';

  @override
  String audioRecordingStartFailure(String error) {
    return 'No se pudo iniciar la grabación: $error';
  }

  @override
  String audioRecordingPauseFailure(String error) {
    return 'No se pudo pausar la grabación: $error';
  }

  @override
  String audioRecordingResumeFailure(String error) {
    return 'No se pudo reanudar la grabación: $error';
  }

  @override
  String get audioRecordingInvalidFile =>
      'El archivo de grabación no es válido. Grabar de nuevo.';

  @override
  String audioRecordingStopFailure(String error) {
    return 'No se pudo detener la grabación: $error';
  }

  @override
  String get audioRecordingFileNotFound => 'Archivo de grabación no encontrado';

  @override
  String get audioRecordingFileEmpty => 'El archivo de grabación está vacío';

  @override
  String audioRecordingSaved(String name) {
    return 'Grabación guardada: $name';
  }

  @override
  String audioRecordingSaveFailure(String error) {
    return 'No se pudo guardar la grabación: $error';
  }

  @override
  String get audioRecordingTitle => 'Grabación';

  @override
  String get audioRecordingBrowserUnsupported =>
      'La grabación no es compatible con el navegador.';

  @override
  String get audioRecordingUseApp =>
      'Utilice la versión de la aplicación para grabar';

  @override
  String get audioRecordingDraftRecoveryHint =>
      'Se encontró un borrador de grabación no guardado. Puede guardarlo en la biblioteca de audio.';

  @override
  String get audioRecordingRecording => 'Grabación ●';

  @override
  String get audioRecordingPaused => 'En pausa ||';

  @override
  String get audioRecordingPreparing => 'Preparante...';

  @override
  String get audioRecordingStart => 'Empezar a grabar';

  @override
  String get audioRecordingPause => 'Pausa';

  @override
  String get audioRecordingStopping => 'Parada...';

  @override
  String get audioRecordingStop => 'Detener';

  @override
  String get audioRecordingResume => 'Reanudar';

  @override
  String get audioRecordingSaving => 'Ahorro...';

  @override
  String get audioRecordingSave => 'Guardar grabación';

  @override
  String get audioRecordingRecordAgain => 'Grabar de nuevo';

  @override
  String get audioRecordingWaveformPaused =>
      'Grabación en pausa; la forma de onda está congelada';

  @override
  String get audioRecordingWaveformLive => 'Forma de onda de audio en vivo';

  @override
  String get audioSeparationTitle => 'Separación de audio y vídeo';

  @override
  String get audioSeparationChooseVideoSource => 'Elige la fuente del vídeo';

  @override
  String get audioSeparationChooseAppAlbum =>
      'Elija de la biblioteca de aplicaciones';

  @override
  String get audioSeparationChooseSavedVideoSubtitle =>
      'Elija un video guardado desde la aplicación';

  @override
  String get audioSeparationChooseSystemAlbum =>
      'Elija entre el almacenamiento del sistema';

  @override
  String get audioSeparationChooseDeviceVideoSubtitle =>
      'Elija un archivo de video del almacenamiento del dispositivo';

  @override
  String audioSeparationChooseVideoFailure(String error) {
    return 'No se pudo elegir el video: $error';
  }

  @override
  String get audioSeparationTaskFailurePrefix =>
      'Error en la extracción de audio:';

  @override
  String get audioSeparationEngineMissing =>
      'Motor de separación de audio no detectado';

  @override
  String get audioSeparationEngineMissingHelp =>
      'Reinicie la aplicación o verifique que sus recursos estén completos.';

  @override
  String get audioSeparationNoVideoSelected => 'Ningún vídeo seleccionado';

  @override
  String get audioSeparationSupportedFormatsHint =>
      'Formatos soportados: mp4, mov, m4v, 3gp';

  @override
  String get audioSeparationSuccess =>
      'Audio extraído y guardado en la biblioteca de audio.';

  @override
  String get audioSeparationView => 'Vista';

  @override
  String audioSeparationSelectedVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se seleccionaron $count videos',
      one: 'Se seleccionó $count video',
    );
    return '$_temp0';
  }

  @override
  String get audioSeparationExtracting => 'Extrayendo...';

  @override
  String get audioSeparationExtractAudio => 'extraer audio';

  @override
  String get audioSeparationSaveTo => 'Guardar en';

  @override
  String get audioSeparationChooseSaveFolder => 'Elija guardar carpeta';

  @override
  String get audioSeparationCannotReadVideoFile =>
      'No se puede leer el archivo de video';

  @override
  String audioSeparationChooseVideoFileFailure(String error) {
    return 'No se pudo seleccionar el archivo de video: $error';
  }

  @override
  String get audioSeparationUnknownFormat => 'Desconocido';

  @override
  String audioSeparationUnsupportedFormats(String formats) {
    return 'Formatos no compatibles: $formats. Formatos soportados: MP4, MOV, M4V, 3GP.';
  }

  @override
  String get audioSeparationEngineUnavailable =>
      'El motor de separación de audio no está disponible.';

  @override
  String get backgroundOptimizationTitle => 'Optimización de fondo';

  @override
  String get backgroundOptimizationEnvironment => 'Entorno del sistema';

  @override
  String get backgroundOptimizationChecks =>
      'Estado del servicio en segundo plano';

  @override
  String get backgroundOptimizationKeepAliveStrategies =>
      'Estrategias para mantenerse vivo';

  @override
  String get backgroundOptimizationDetecting => 'De cheques…';

  @override
  String get backgroundOptimizationUnsupportedStatus =>
      'Los servicios en segundo plano no son compatibles con esta plataforma';

  @override
  String get backgroundOptimizationServiceRunning =>
      'El servicio en segundo plano se está ejecutando';

  @override
  String get backgroundOptimizationServiceStopped =>
      'El servicio en segundo plano no se está ejecutando';

  @override
  String get backgroundOptimizationServiceCheckFailed =>
      'No se pudo verificar el estado del servicio en segundo plano';

  @override
  String get backgroundOptimizationDesktopTrayUnavailable =>
      'La bandeja del escritorio no está disponible. Al cerrar la ventana se saldrá de la aplicación.';

  @override
  String get backgroundOptimizationDesktopCloseExits =>
      'La aplicación se cierra cuando se cierra la ventana del escritorio.';

  @override
  String get backgroundOptimizationDesktopTrayKeepsAlive =>
      'La bandeja del escritorio mantiene la aplicación en funcionamiento.';

  @override
  String get backgroundOptimizationStartFailed =>
      'No se pudo iniciar el servicio';

  @override
  String get backgroundOptimizationStopFailed =>
      'No se pudo detener el servicio';

  @override
  String get backgroundOptimizationRestartFailed =>
      'No se pudo reiniciar el servicio';

  @override
  String get backgroundOptimizationStopService => 'Detener servicio';

  @override
  String get backgroundOptimizationRestartService => 'Reiniciar servicio';

  @override
  String get backgroundOptimizationStartService => 'Iniciar servicio';

  @override
  String get backgroundOptimizationRedetect => 'Comprobar de nuevo';

  @override
  String get backgroundOptimizationUnsupportedControl =>
      'Los controles de servicios en segundo plano no son compatibles con esta plataforma.';

  @override
  String get backgroundOptimizationCheckingBattery =>
      'Comprobando el estado de optimización de la batería...';

  @override
  String get backgroundOptimizationBatteryIgnored =>
      'La optimización de la batería está deshabilitada para esta aplicación';

  @override
  String get backgroundOptimizationBatteryMayKill =>
      'La optimización de la batería está habilitada: es posible que se detenga la actividad en segundo plano';

  @override
  String get backgroundOptimizationIgnoreBattery =>
      'Deshabilitar la optimización de la batería';

  @override
  String get backgroundOptimizationExactAlarm =>
      'Permitir alarmas exactas (actividad en segundo plano más confiable)';

  @override
  String get backgroundOptimizationWatchdogTitle =>
      'Perro guardián del administrador de alarmas';

  @override
  String get backgroundOptimizationWatchdogDetail =>
      'Cuando está habilitado, Android verifica el servicio en segundo plano cada 5 minutos usando una alarma nativa. Si el sistema finaliza el proceso, la alarma lo reinicia.\n\nLa alarma sigue funcionando mientras el dispositivo está en modo Doze y se reprograma después de reiniciar.\n\nRecomendado para usuarios que dependen en gran medida de tareas en segundo plano.\nImpacto de la batería: muy bajo; el dispositivo se activa brevemente para cada comprobación.';

  @override
  String get backgroundOptimizationSaveWatchdogFailed =>
      'No se pudo guardar la configuración de vigilancia; no fue cambiado';

  @override
  String get backgroundOptimizationWatchdogActivationFailed =>
      'No se pudo activar el perro guardián; el estado del servicio en segundo plano no está confirmado';

  @override
  String get backgroundOptimizationColdStartTitle =>
      'Restaurar el servicio al iniciar la aplicación';

  @override
  String get backgroundOptimizationColdStartDetail =>
      'Cuando está habilitada, la aplicación busca y restaura un servicio en segundo plano que se esté ejecutando previamente cada vez que se abre.\n\nSi el sistema o el usuario detiene el proceso de la aplicación, el servicio en segundo plano se reinicia la próxima vez que abra la aplicación.\n\nRecomendado para todos los usuarios.\nImpacto de la batería: ninguno; la aplicación verifica solo una vez al iniciarse.';

  @override
  String get backgroundOptimizationSaveColdStartFailed =>
      'No se pudo guardar la configuración de recuperación de inicio; no fue cambiado';

  @override
  String get backgroundOptimizationBatteryReminderTitle =>
      'Recordatorio de optimización de la batería';

  @override
  String get backgroundOptimizationBatteryReminderDetail =>
      'Cuando está habilitada, esta página muestra el estado de optimización de la batería. Si la aplicación no está en la lista de exención de batería, puede abrir la configuración del sistema para eximirla.\n\nLa optimización de la batería de Android (Doze) limita las aplicaciones en segundo plano. Agregar esta aplicación a la lista de exenciones evita que el sistema la detenga para ahorrar energía.\n\nDesactivar esto solo oculta la tarjeta de recordatorio; no cambia la exención de batería de la aplicación.';

  @override
  String get backgroundOptimizationStrategyIntro =>
      'Estas estrategias se pueden habilitar de forma independiente. Todos están activados de forma predeterminada para que la actividad en segundo plano sea más confiable. Desactivar uno afecta sólo a esa estrategia, no al servicio en segundo plano en sí.';

  @override
  String get backgroundOptimizationIosNoteTitle =>
      'Tareas en segundo plano de iOS';

  @override
  String get backgroundOptimizationIosSupported =>
      'Esta versión de iOS (26 o posterior) admite tareas en segundo plano en curso. Las tareas generalmente continúan cuando cambias de aplicación o bloqueas la pantalla, aunque el sistema puede detenerlas cuando los recursos son bajos. Puedes ver el progreso en la pantalla de bloqueo.';

  @override
  String get backgroundOptimizationIosUnsupported =>
      'Esta versión de iOS (anterior a la 26) no admite tareas en segundo plano en curso. Mientras se ejecuta una tarea, regrese a la aplicación cada pocos minutos (aproximadamente cada 5 a 10 minutos; el tiempo depende de iOS) para actualizar su tiempo de fondo y evitar la suspensión.';

  @override
  String get backgroundOptimizationIosWarning =>
      'En todas las versiones de iOS, no deslices Stroom en el selector de aplicaciones. Al hacerlo, se detendrán inmediatamente todas las tareas en ejecución.';

  @override
  String get backgroundOptimizationDesktopIntro =>
      'Los sistemas de escritorio no tienen el mecanismo de mantenimiento de procesos de las plataformas móviles, pero la aplicación puede continuar ejecutándose después de que se cierra la ventana.';

  @override
  String get backgroundOptimizationCloseMinimizeTitle =>
      'Minimizar al cerrar la ventana';

  @override
  String get backgroundOptimizationCloseMinimizeDetail =>
      'Cuando está habilitado, al hacer clic en el botón de cerrar de la ventana se oculta la aplicación en la bandeja del sistema en lugar de salir. Las tareas en segundo plano continúan ejecutándose.\n\nRestaure la ventana desde el icono de la bandeja o su elemento de menú \"Mostrar ventana principal\". Para salir, utilice el botón \"Salir de la aplicación\" que aparece a continuación.\n\nRecomendado para todos los usuarios de escritorio.';

  @override
  String get backgroundOptimizationQuitApp => 'Salir de la aplicación';

  @override
  String get backgroundOptimizationGotIt => 'Entiendo';

  @override
  String get backgroundOptimizationWebNoteTitle =>
      'Tareas web en segundo plano';

  @override
  String get backgroundOptimizationWebNote =>
      'Los navegadores no pueden mantener las aplicaciones ejecutándose en segundo plano. Al cerrar o actualizar esta pestaña, o si el navegador congela una pestaña en segundo plano inactiva, se detiene inmediatamente la ejecución de tareas. Mantenga la pestaña Stroom abierta y en primer plano mientras se ejecutan las tareas.';

  @override
  String get backgroundOptimizationTutorial => 'Guías de plataforma';

  @override
  String get backgroundOptimizationTutorialDescription =>
      'Ver guías de optimización en segundo plano para cada plataforma';

  @override
  String get backgroundOptimizationServiceCheckingDescription =>
      'Comprobando el estado del servicio en segundo plano...';

  @override
  String get backgroundOptimizationServiceUnknown =>
      'Se desconoce el estado del servicio en segundo plano. Verifique nuevamente para confirmar si el servicio se está ejecutando.';

  @override
  String get backgroundOptimizationServiceRunningDescription =>
      'El servicio en segundo plano se está ejecutando. Las tareas pueden continuar en segundo plano.';

  @override
  String get backgroundOptimizationWebServiceUnsupported =>
      'Los servicios en segundo plano no son compatibles con los navegadores web. Mantenga esta página abierta para continuar con las tareas.';

  @override
  String get backgroundOptimizationLinuxTrayUnavailable =>
      'La bandeja del escritorio no está disponible (las compilaciones de Linux requieren libayatana-appindicator3-dev). Al cerrar la ventana se saldrá de la aplicación.';

  @override
  String get backgroundOptimizationDesktopTrayUnavailableDescription =>
      'La bandeja del escritorio no está disponible. Al cerrar la ventana se saldrá de la aplicación.';

  @override
  String get backgroundOptimizationDesktopExitDescription =>
      'La aplicación está configurada para salir cuando se cierra la ventana del escritorio. Seguirá el flujo de confirmación de salida existente y no continuará ejecutándose en la bandeja.';

  @override
  String get backgroundOptimizationLinuxTrayDescription =>
      'La bandeja del escritorio está habilitada. Al cerrar la ventana, se oculta la aplicación en la bandeja del sistema, donde continúa ejecutándose. Seleccione \"Mostrar ventana principal\" en el menú de la bandeja para restaurarla. Para salir por completo, seleccione \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get backgroundOptimizationDesktopTrayDescription =>
      'La bandeja del escritorio está habilitada. Cerrar la ventana minimiza la aplicación en la bandeja del sistema, donde continúa ejecutándose. Haga clic en el icono de la bandeja o seleccione \"Mostrar ventana principal\" en su menú para restaurar la ventana. Para salir por completo, seleccione \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get backgroundOptimizationServiceNotRunningDescription =>
      'El servicio en segundo plano no se está ejecutando. Seleccione \"Iniciar servicio\" a continuación o consulte las guías de la plataforma para aprender cómo optimizar la actividad en segundo plano.';

  @override
  String get notificationSettingsPageTitle =>
      'Configuración de permisos de notificación';

  @override
  String get notificationSettingsWebUnsupported =>
      'Las notificaciones no son compatibles con los navegadores web.';

  @override
  String get notificationSettingsChecking => 'De cheques…';

  @override
  String get notificationSettingsPermissionGranted =>
      'Permiso de notificación concedido';

  @override
  String get notificationSettingsPermissionDenied =>
      'Permiso de notificación no concedido';

  @override
  String get notificationSettingsPermissionRestricted =>
      'Permiso de notificación restringido';

  @override
  String get notificationSettingsPermissionBlocked =>
      'Permiso de notificación bloqueado permanentemente';

  @override
  String get notificationSettingsPermissionProvisional =>
      'Permiso de notificación provisional';

  @override
  String get notificationSettingsWebGuide =>
      'Las notificaciones del sistema no son compatibles con los navegadores web.';

  @override
  String get notificationSettingsCheckingPermission =>
      'Comprobando el permiso de notificación...';

  @override
  String get notificationSettingsPermissionGrantedGuide =>
      'Se concede el permiso de notificación. Puede habilitar las notificaciones de finalización de tareas para recibir alertas del sistema cuando una tarea se completa o falla.';

  @override
  String get notificationSettingsPermissionDeniedGuide =>
      'No se ha concedido el permiso de notificación. Seleccione el botón a continuación para solicitar permiso o habilitar notificaciones para Stroom en la configuración del sistema.';

  @override
  String get notificationSettingsPermissionRestrictedGuide =>
      'El permiso de notificación está restringido por el sistema, por ejemplo mediante controles parentales. Verifique la configuración de notificaciones de Stroom en la configuración del sistema.';

  @override
  String get notificationSettingsEnvironment => 'Entorno del sistema';

  @override
  String get notificationSettingsPermissionSection => 'Permiso de notificación';

  @override
  String get notificationSettingsPlatformGuides => 'Guía de plataforma';

  @override
  String get notificationSettingsGuideIntro =>
      'Siga estos pasos para que su sistema operativo habilite las notificaciones de Stroom.';

  @override
  String get notificationSettingsTaskCompleteTitle =>
      'Notificaciones de finalización de tareas';

  @override
  String get notificationSettingsTaskCompleteDescription =>
      'Enviar una notificación cuando una tarea se complete o falle';

  @override
  String get notificationSettingsCheckAgain => 'Comprobar de nuevo';

  @override
  String get notificationSettingsOpenSystemSettings =>
      'Abrir configuración del sistema';

  @override
  String get notificationSettingsRequestPermission => 'Solicitar permiso';

  @override
  String get notificationSettingsGuideUnsupported =>
      'Las guías de configuración de notificaciones no están disponibles para esta plataforma.';

  @override
  String get notificationSettingsUsageReason =>
      'Para enviar notificaciones cuando se completen las tareas';

  @override
  String get notificationSettingsAndroidEnableTitle =>
      'Habilitar notificaciones';

  @override
  String get notificationSettingsAndroidEnableDescription =>
      'Vaya a Configuración → Aplicaciones → Stroom → Gestión de notificaciones y permita notificaciones. Si no puede encontrar Stroom, asegúrese de que esté instalado. Si las notificaciones están deshabilitadas, actívelas.';

  @override
  String get notificationSettingsAndroidDndTitle => 'Marque No molestar';

  @override
  String get notificationSettingsAndroidDndDescription =>
      'Vaya a Configuración → Sonido y vibración → No molestar. Asegúrate de que esté apagado o que las notificaciones de Stroom estén permitidas.';

  @override
  String get notificationSettingsAndroidPopupTitle =>
      'Permitir que aparezcan notificaciones emergentes';

  @override
  String get notificationSettingsAndroidPopupDescription =>
      'Algunos sistemas Android, como MIUI, EMUI y ColorOS, requieren que \"Permitir notificaciones\" y \"Permitir ventanas emergentes\" estén habilitados en Información de la aplicación. También considere desactivar el “Filtrado de notificaciones” o las “Notificaciones inteligentes” para la aplicación.';

  @override
  String get notificationSettingsReturnTitle => 'Regresar a esta página';

  @override
  String get notificationSettingsAndroidReturnDescription =>
      'Después de cambiar esta configuración, seleccione \"Verificar nuevamente\" para confirmar el estado del permiso. Cuando se concede el permiso, puede habilitar las notificaciones de finalización de tareas.';

  @override
  String get notificationSettingsIosEnableDescription =>
      'Vaya a Configuración → Notificaciones → Stroom y active “Permitir notificaciones”. También habilite los banners y el centro de notificaciones para mantenerse actualizado sobre el estado de las tareas.';

  @override
  String get notificationSettingsIosFocusTitle => 'Desactivar el enfoque';

  @override
  String get notificationSettingsIosFocusDescription =>
      'Vaya a Configuración → Enfoque. Asegúrate de que Focus esté desactivado o agrega Stroom a la lista de aplicaciones permitidas. Focus puede silenciar las notificaciones de aplicaciones.';

  @override
  String get notificationSettingsIosReturnDescription =>
      'Después de cambiar esta configuración, seleccione \"Verificar nuevamente\" para confirmar el estado del permiso. En iOS, el permiso de notificación generalmente debe habilitarse manualmente en la configuración del sistema.';

  @override
  String get notificationSettingsWindowsEnableTitle =>
      'Habilitar notificaciones del sistema';

  @override
  String get notificationSettingsWindowsEnableDescription =>
      'Vaya a Configuración → Sistema → Notificaciones y acciones y active \"Recibir notificaciones de aplicaciones y otros remitentes\". Busque Stroom en la lista de aplicaciones a continuación y asegúrese de que sus notificaciones estén activadas.';

  @override
  String get notificationSettingsWindowsFocusTitle =>
      'Agregar una excepción de asistencia de enfoque';

  @override
  String get notificationSettingsWindowsFocusDescription =>
      'Vaya a Configuración → Sistema → Asistente de enfoque. Agregue Stroom a \"Solo prioridad\" o desactive Focus Assist; Focus Assist puede silenciar las notificaciones.';

  @override
  String get notificationSettingsMacEnableTitle => 'Habilitar notificaciones';

  @override
  String get notificationSettingsMacEnableDescription =>
      'Vaya a Configuración del sistema → Notificaciones → Stroom y active “Permitir notificaciones”. Habilite también los banners y el centro de notificaciones.';

  @override
  String get notificationSettingsMacFocusDescription =>
      'Vaya a Configuración del sistema → Enfoque. Asegúrate de que Focus esté desactivado o agrega Stroom a la lista de aplicaciones permitidas.';

  @override
  String get notificationSettingsLinuxDesktopTitle =>
      'Verifique la configuración de notificaciones de escritorio';

  @override
  String get notificationSettingsLinuxDesktopDescription =>
      'Dependiendo de su entorno de escritorio (GNOME, KDE, XFCE, etc.), vaya a Configuración del sistema → Notificaciones, busque Stroom y asegúrese de que las notificaciones estén activadas.';

  @override
  String get notificationSettingsLinuxDaemonTitle =>
      'Verifique el demonio de notificación';

  @override
  String get notificationSettingsLinuxDaemonDescription =>
      'Los entornos de escritorio Linux necesitan un demonio de notificación, como notify-osd o dunst, para mostrar las notificaciones del sistema. Asegúrese de que uno esté instalado y ejecutándose.';

  @override
  String get backupRestorePageTitle => 'Copia de seguridad y restauración';

  @override
  String get backupRestoreSelectBackupCategory =>
      'Seleccione al menos una categoría de datos para realizar una copia de seguridad';

  @override
  String get backupRestorePreparingData => 'Preparando datos…';

  @override
  String get backupRestoreExportingBackup => 'Exportando copia de seguridad';

  @override
  String get backupRestoreCollectingDatabase =>
      'Recopilando registros de bases de datos...';

  @override
  String get backupRestoreProcessingSettings =>
      'Configuración de procesamiento…';

  @override
  String get backupRestoreAddingTasks => 'Agregando archivos de tareas…';

  @override
  String get backupRestoreAddingPictures => 'Agregando archivos de imagen…';

  @override
  String get backupRestoreAddingAudio => 'Agregando archivos de audio…';

  @override
  String get backupRestoreAddingVideo => 'Agregando archivos de vídeo…';

  @override
  String get backupRestoreAddingText => 'Agregando archivos de texto…';

  @override
  String get backupRestoreAddingChat =>
      'Agregando historial de chat y archivos adjuntos...';

  @override
  String get backupRestoreCompressing => 'Comprimiendo archivo…';

  @override
  String get backupRestoreCompleted => 'Completo';

  @override
  String get backupRestoreSelectRestoreCategory =>
      'Seleccione al menos una categoría de datos para restaurar';

  @override
  String get backupRestoreConfirmRestore => 'Confirmar restauración';

  @override
  String get backupRestoreSelectedCategories =>
      'Categorías de datos seleccionadas:';

  @override
  String get backupRestoreRestoreInfo =>
      'Las categorías seleccionadas que se encuentren en la copia de seguridad se restaurarán en este dispositivo. Todas las categorías, excepto las cookies integradas en el navegador, reemplazan los datos locales correspondientes. Las cookies se escriben por dominio, nombre y ruta; Se conservan las cookies locales no incluidas en la copia de seguridad. Las categorías no seleccionadas y las categorías que faltan en la copia de seguridad permanecen sin cambios. Las categorías que faltan se omiten con un aviso.';

  @override
  String get backupRestoreRestartNotice =>
      'Reinicie la aplicación después de restaurarla para que los cambios surtan efecto. Asegúrese de que su trabajo actual esté guardado.';

  @override
  String get backupRestoreCancel => 'Cancelar';

  @override
  String get backupRestoreConfirmRestoreButton => 'Restaurar';

  @override
  String get backupRestoreIncompleteTitle => 'Restaurar incompleto';

  @override
  String get backupRestoreIncompleteMessage =>
      'Los datos no se pudieron restaurar completamente y es posible que algunos datos se hayan borrado. Reinicie la aplicación y vuelva a intentarlo.';

  @override
  String get backupRestoreSelectClearCategory =>
      'Seleccione al menos una categoría de datos para borrar';

  @override
  String get backupRestoreClearingData => 'Borrar datos';

  @override
  String get backupRestoreDeletingCategories =>
      'Eliminando categorías de datos seleccionadas...';

  @override
  String get backupRestoreClearedTitle => 'Datos borrados';

  @override
  String get backupRestorePartiallyClearedTitle => 'Algunos datos borrados';

  @override
  String get backupRestoreClearedMessage =>
      'Se borraron los datos seleccionados. Reinicie la aplicación para que los cambios surtan efecto.';

  @override
  String get backupRestorePartialClearMessage =>
      'Se borraron otros datos seleccionados. Esta plataforma no puede borrar completamente el almacenamiento integrado del sitio web del navegador (localStorage, IndexedDB, etc.), por lo que los datos del navegador que no se pudieron borrar permanecen. Reinicie la aplicación para que los datos borrados surtan efecto.';

  @override
  String backupRestoreClearFailed(String error) {
    return 'No se pudieron borrar los datos: $error';
  }

  @override
  String get backupRestoreClearIncompleteTitle => 'Borrar incompleto';

  @override
  String get backupRestoreClearIncompleteMessage =>
      'Algunos datos no se pudieron borrar. Reinicie la aplicación e intente borrarla nuevamente.';

  @override
  String backupRestoreAnkiExportSuccess(String path) {
    return 'Cubierta Anki exportada a: $path';
  }

  @override
  String backupRestoreExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get backupRestoreApkgRequired => 'Seleccione un archivo .apkg';

  @override
  String backupRestoreImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String backupServiceExportSavedTo(String location) {
    return 'Copia de seguridad guardada en: $location';
  }

  @override
  String backupServiceExportFailed(String error) {
    return 'Error en la copia de seguridad: $error';
  }

  @override
  String backupServiceRestoreFailed(String error) {
    return 'Error de restauración: $error';
  }

  @override
  String get backupServiceNoBackupFolderSelected =>
      'No se ha seleccionado ninguna carpeta de respaldo. Autorice uno durante el inicio.';

  @override
  String get backupRestoreRestoreSuccessTitle => 'Datos restaurados';

  @override
  String get backupRestoreRestoredMessage =>
      'Los datos fueron restaurados desde la copia de seguridad. Reinicie la aplicación para utilizar los datos restaurados.';

  @override
  String get backupRestoreExitApp => 'Salir de la aplicación';

  @override
  String get backupRestoreRestartNow => 'Reiniciar ahora';

  @override
  String get backupRestoreSkippedTitle => 'Algunos datos omitidos';

  @override
  String get backupRestoreNothingRestoredTitle => 'No se restauraron datos';

  @override
  String get backupRestoreGotIt => 'Entiendo';

  @override
  String backupRestoreSkippedCategories(String categories) {
    return 'La copia de seguridad no confirmó el contenido restaurable para estas categorías seleccionadas, por lo que se omitieron y se conservaron los datos existentes: $categories.';
  }

  @override
  String get backupRestoreSkippedTasksLegacy =>
      'En copias de seguridad más antiguas, un archivo de tareas vacío no puede distinguir una lista de tareas vacía de tareas no exportadas por esa plataforma. Para evitar sobrescribir las tareas actuales, se omitió la categoría de tarea y se mantuvieron los datos existentes.';

  @override
  String get backupRestoreSkippedCookies =>
      'La copia de seguridad no contiene cookies integradas del navegador para importar, por lo que se omitió esta categoría y se mantuvieron las cookies existentes.';

  @override
  String get backupRestoreSkippedWebsiteData =>
      'Se omitió el directorio de almacenamiento del sitio web en esta copia de seguridad anterior. Las cookies aún se pueden importar por separado si el archivo las contiene y se selecciona esa categoría.';

  @override
  String get backupRestoreApkgTitle => 'Cubierta Anki';

  @override
  String get backupRestoreApkgInfoTitle =>
      'Importar o exportar una baraja Anki';

  @override
  String get backupRestoreApkgInfoMessage =>
      'Incluye información de la tarjeta únicamente, no medios';

  @override
  String get backupRestoreApkgDescription =>
      'Importa o exporta mazos de Anki en formato .apkg';

  @override
  String get backupRestoreExportingApkg => 'Exportador…';

  @override
  String get backupRestoreExportApkg => 'Exportar .apkg';

  @override
  String get backupRestoreImportingApkg => 'Importador…';

  @override
  String get backupRestoreImportApkg => 'Importar .apkg';

  @override
  String get backupRestoreCategoryHeading =>
      'Elija categorías de datos para realizar una copia de seguridad o restaurar';

  @override
  String get backupRestoreExporting => 'Exportador…';

  @override
  String get backupRestoreExportBackup => 'Exportar copia de seguridad';

  @override
  String get backupRestoreRestoring => 'Restaurando…';

  @override
  String get backupRestoreChooseBackup =>
      'Elija el archivo de copia de seguridad y restaure';

  @override
  String get backupRestoreClearSelected => 'Borrar datos seleccionados';

  @override
  String get backupRestoreClearDescription =>
      'Borre las categorías de datos seleccionadas directamente sin un archivo de respaldo. Las categorías no seleccionadas permanecerán sin cambios. Esta acción no se puede deshacer.';

  @override
  String get backupRestoreClearing => 'Borrando…';

  @override
  String get backupRestoreCategoryChat =>
      'Historial de chat y archivos adjuntos';

  @override
  String get backupRestoreCategoryChatDescription =>
      'Conversaciones de chat, contenido de mensajes y archivos adjuntos';

  @override
  String get backupRestoreCategorySettings => 'Ajustes';

  @override
  String get backupRestoreCategorySettingsDescription =>
      'Configuración de la aplicación, configuración del proveedor y preferencias de la interfaz';

  @override
  String get backupRestoreCategoryPictures => 'Imágenes';

  @override
  String get backupRestoreCategoryPicturesDescription => 'Fotos y miniaturas';

  @override
  String get backupRestoreCategoryAudio => 'Audio';

  @override
  String get backupRestoreCategoryAudioDescription =>
      'Síntesis de voz y grabaciones.';

  @override
  String get backupRestoreCategoryVideos => 'Vídeos';

  @override
  String get backupRestoreCategoryVideosDescription => 'Archivos de vídeo';

  @override
  String get backupRestoreCategoryTexts => 'Texto';

  @override
  String get backupRestoreCategoryTextsDescription => 'Documentos de texto';

  @override
  String get backupRestoreCategoryTasks => 'Tareas';

  @override
  String get backupRestoreCategoryTasksDescription =>
      'Registros de tareas en segundo plano';

  @override
  String get backupRestoreCategoryAnki =>
      'Datos de la tarjeta didáctica de Anki';

  @override
  String get backupRestoreCategoryAnkiDescription => 'base de datos anki';

  @override
  String get backupRestoreAnkiDataInfoTitle =>
      'Datos de la tarjeta didáctica de Anki';

  @override
  String get backupRestoreAnkiDataInfoMessage =>
      'Hacer una copia de seguridad o restaurar los datos de la tarjeta flash Anki también incluye los medios de la tarjeta en el directorio collection.media.';

  @override
  String get backupRestoreAnkiDataInfoTooltip =>
      'Acerca de los datos de Anki Flashcard';

  @override
  String get backupRestoreCategoryBrowser => 'Datos del navegador integrados';

  @override
  String get backupRestoreCategoryBrowserDescription =>
      'Realiza copias de seguridad y restaura cookies únicamente; La limpieza también elimina el almacenamiento del sitio web compatible.';

  @override
  String get backupRestoreViewInfo => 'Ver información';

  @override
  String get backupRestoreApkgInfoTooltip =>
      'Acerca de la importación y exportación de Anki Deck';

  @override
  String get backupRestoreConfirmClear => 'Confirmar Borrar';

  @override
  String get backupRestoreClearCategoriesIntro =>
      'Las siguientes categorías de datos se borrarán sin utilizar un archivo de copia de seguridad:';

  @override
  String get backupRestoreBrowserClearUnsupported =>
      'Esta plataforma no puede borrar completamente el almacenamiento del sitio web integrado del navegador (localStorage, IndexedDB, etc.). Al confirmar se borran los demás datos seleccionados; Los datos del navegador que no se puedan borrar permanecerán.';

  @override
  String get backupRestoreUnselectedUnchanged =>
      'Las categorías no seleccionadas permanecerán sin cambios.';

  @override
  String get backupRestoreClearWarning =>
      'Esta acción no se puede deshacer. Reinicie la aplicación después de borrarla para que los cambios surtan efecto.';

  @override
  String backupRestoreConfirmClearCountdown(int seconds) {
    return 'Borrar ($seconds)';
  }

  @override
  String get backgroundOptimizationBrowserEnvironment =>
      'Entorno del navegador';

  @override
  String get backupRestoreIntro =>
      'Exporte las categorías de datos seleccionadas manualmente. Durante la importación, solo se restauran las categorías seleccionadas que se encuentran en el archivo. Una categoría faltante o un archivo requerido se omite con un aviso y las categorías no seleccionadas permanecen sin cambios. También puede borrar las categorías seleccionadas directamente.';

  @override
  String get backupRestoreOtherSelectedRestored =>
      'Los demás datos seleccionados fueron restaurados. Reinicie la aplicación para que los cambios surtan efecto.';

  @override
  String get notificationSettingsPermissionBlockedGuide =>
      'Las notificaciones están bloqueadas. Abra la configuración del sistema y permita notificaciones para Stroom.';

  @override
  String get notificationSettingsPermissionBlockedAndroid =>
      'Las notificaciones están bloqueadas. Vaya a Configuración del sistema → Aplicaciones → Stroom → Gestión de notificaciones y permita notificaciones.';

  @override
  String get notificationSettingsPermissionBlockedIos =>
      'Las notificaciones están bloqueadas. Vaya a Configuración del sistema → Stroom → Notificaciones y permita notificaciones.';

  @override
  String get textPreviewDiscardEditsTitle => '¿Descartar ediciones?';

  @override
  String get textPreviewUnsavedChangesConfirm =>
      'Tienes cambios sin guardar. ¿Estás seguro de que quieres descartarlos?';

  @override
  String get textPreviewCancel => 'Cancelar';

  @override
  String get textPreviewDiscard => 'Desechar';

  @override
  String get textPreviewFontSize => 'Ajustar el tamaño de fuente';

  @override
  String get textPreviewRestoreDefault => 'Restaurar valor predeterminado';

  @override
  String get textPreviewClose => 'Cerrar';

  @override
  String textPreviewSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get textPreviewUndo => 'Deshacer';

  @override
  String get textPreviewRedo => 'Rehacer';

  @override
  String get textPreviewSave => 'Guardar';

  @override
  String get textPreviewEdit => 'Editar';

  @override
  String get textPreviewChartEdit => 'Editar gráfico';

  @override
  String textStorageSkipUnsupportedFormat(String format) {
    return 'Formato no compatible omitido: $format';
  }

  @override
  String textStorageImportSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# archivos de texto',
      one: '# archivo de texto',
    );
    return 'Se importó $_temp0';
  }

  @override
  String textStorageImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String get textStorageSaved => 'Texto guardado';

  @override
  String get textStorageLoadFailed => 'No se puede cargar contenido de texto';

  @override
  String get textStorageReadFailed =>
      'No se pudieron leer los datos del archivo';

  @override
  String get textStorageExportTitle => 'Exportar texto';

  @override
  String textStorageExportedTo(String path) {
    return 'Exportado a: $path';
  }

  @override
  String textStorageExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get textStorageChooseExportDirectory =>
      'Elija el directorio de exportación';

  @override
  String get textStorageFolderExportTitle => 'Exportar carpeta';

  @override
  String get textStorageWebFolderExportInfo =>
      'El navegador no puede seleccionar un directorio de exportación. Se descargará un archivo ZIP que conserva la estructura de carpetas.';

  @override
  String get textStorageCancel => 'Cancelar';

  @override
  String get textStorageDownloadZip => 'Descargar archivo ZIP';

  @override
  String textStorageExportedFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# archivos',
      one: '# archivo',
    );
    return 'Se exportó $_temp0';
  }

  @override
  String get textStorageExportFolderTitle => 'Exportar carpeta de texto';

  @override
  String textStorageCopyFailed(String error) {
    return 'Copia fallida: $error';
  }

  @override
  String get textStorageCreateNew => 'Nuevo';

  @override
  String get textStorageImport => 'Importar';

  @override
  String get textStorageTitle => 'Texto';

  @override
  String get textStorageExportToLocal => 'Exportar a local';

  @override
  String get textCreateEnterTitle => 'Por favor introduce un título';

  @override
  String textCreateSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get textCreateNewTitle => 'Nuevo';

  @override
  String get textCreateSave => 'Guardar';

  @override
  String get textCreateTitleLabel => 'Título';

  @override
  String get textCreateTitleHint => 'Introduzca el título del texto';

  @override
  String get textCreateFormatLabel => 'Formato';

  @override
  String get textCreateContentLabel => 'Contenido del texto';

  @override
  String get textCreateContentHint => 'Introduzca el contenido del texto...';

  @override
  String platformTutorialPlatformSubtitle(Object platform) {
    return 'Tutorial de optimización en segundo plano $platform';
  }

  @override
  String platformTutorialDetailTitle(Object platform) {
    return 'Guía de ejecución en segundo plano $platform';
  }

  @override
  String platformTutorialGuideTitle(Object platform) {
    return 'Guía de optimización en segundo plano $platform';
  }

  @override
  String platformTutorialGuideIntro(Object platform) {
    return 'Estos pasos pueden ayudar a optimizar la experiencia en segundo plano de Stroom en dispositivos $platform para que las tareas puedan continuar ejecutándose en segundo plano.';
  }

  @override
  String get platformTutorialStepsHeading => 'Pasos de optimización';

  @override
  String get platformTutorialTipsHeading => 'Consejo';

  @override
  String get platformTutorialTipsDescription =>
      'Después de completar esta configuración, regrese a la página \"Optimización de fondo\" y verifique que el estado se haya actualizado. Si aún tiene problemas, consulte la guía de otra plataforma o informe el problema en GitHub.';

  @override
  String get platformTutorialAndroidStep1Title =>
      'Desactivar la optimización de la batería';

  @override
  String get platformTutorialAndroidStep1Description =>
      'Abra Configuración → Aplicaciones → Stroom → Batería, luego elija “Sin restricciones” o “No optimizar”. También puede tocar \"Ignorar optimización de la batería\" en la página \"Optimización en segundo plano\" de esta aplicación para agregar Stroom a la lista de permitidos de ahorro de energía del sistema. Las rutas varían según la marca del dispositivo.';

  @override
  String get platformTutorialAndroidStep2Title =>
      'Permitir actividad en segundo plano';

  @override
  String get platformTutorialAndroidStep2Description =>
      'Abra Configuración → Aplicaciones → Stroom y habilite “Permitir actividad en segundo plano” y “Permitir inicio automático”. Algunos teléfonos también requieren permitir el inicio automático en Security Center o Phone Manager.';

  @override
  String get platformTutorialAndroidStep3Title =>
      'Bloquear el proceso en segundo plano';

  @override
  String get platformTutorialAndroidStep3Description =>
      'En la vista de aplicaciones recientes, deslice hacia abajo la tarjeta Stroom o toque su ícono de candado para evitar que el sistema borre la aplicación.';

  @override
  String get platformTutorialAndroidStep4Title =>
      'Permitir notificaciones (Android 13+)';

  @override
  String get platformTutorialAndroidStep4Description =>
      'Android 13 y versiones posteriores requieren permiso de notificación. Sin él, la notificación en primer plano para el servicio en segundo plano está oculta, aunque el servicio aún se ejecuta. La aplicación solicita permiso cuando tocas por primera vez \"Iniciar servicio\", o puedes habilitarlo en Configuración → Aplicaciones → Stroom → Notificaciones.';

  @override
  String get platformTutorialAndroidStep5Title =>
      'Ignorar la optimización de la batería';

  @override
  String get platformTutorialAndroidStep5Description =>
      'Cuando habilitas las “Notificaciones de finalización de tareas” en Stroom, la aplicación solicita el permiso relacionado. También puede verificar que Stroom esté configurado en \"No optimizar\" en Configuración → Aplicaciones → Acceso a aplicaciones especiales → Optimización de la batería.';

  @override
  String get platformTutorialAndroidStep6Title =>
      'Inicio automático y gestión en segundo plano en dispositivos Android';

  @override
  String get platformTutorialAndroidStep6Description =>
      'Los fabricantes de dispositivos suelen añadir sus propios controles en segundo plano:\n• Xiaomi/Redmi (MIUI/HyperOS): Configuración → Aplicaciones → Permisos → Inicio automático; permitir Stroom. Luego abra Batería → Ahorro de batería de la aplicación → Stroom → Sin restricciones.\n• Huawei/Honor (EMUI/HarmonyOS): Configuración → Aplicaciones → Inicio de aplicación → Stroom → Administrar manualmente; permitir el inicio automático, el inicio secundario y la actividad en segundo plano.\n• OPPO/OnePlus/realme (ColorOS): Configuración → Batería → Gestión de batería de la aplicación → Stroom; permitir actividad en segundo plano completa.\n• vivo/iQOO (OriginOS): iManager → Gestión de aplicaciones → Inicio automático; permitir Stroom.';

  @override
  String get platformTutorialAndroidStep7Title =>
      'Desactivar la limpieza de la pantalla de bloqueo y los modos de ahorro de energía';

  @override
  String get platformTutorialAndroidStep7Description =>
      'Abra Configuración → Batería y desactive \"Ahorro de energía\" o \"Ultra ahorro de energía\". También configure \"Borrar memoria después de bloquear\" en \"No borrar\". Los modos de ahorro de energía restringen la actividad en segundo plano y pueden afectar la finalización de la tarea.';

  @override
  String get platformTutorialIosStep1Title =>
      'Habilitar actualización de la aplicación en segundo plano';

  @override
  String get platformTutorialIosStep1Description =>
      'Abra Configuración → General → Actualización de la aplicación en segundo plano, busque Stroom y actívelo. Elija \"Wi-Fi y datos móviles\" para disfrutar de la mejor experiencia.';

  @override
  String get platformTutorialIosStep2Title => 'Permitir notificaciones';

  @override
  String get platformTutorialIosStep2Description =>
      'Abra Configuración → Notificaciones → Stroom y active “Permitir notificaciones”. Habilite los banners y el Centro de notificaciones para que pueda ver las actualizaciones de tareas rápidamente.';

  @override
  String get platformTutorialIosStep3Title =>
      'Desactivar el modo de bajo consumo';

  @override
  String get platformTutorialIosStep3Description =>
      'Abra Configuración → Batería y desactive el \"Modo de bajo consumo\". El sistema restringe la actividad en segundo plano mientras este modo está activado.';

  @override
  String get platformTutorialIosStep4Title =>
      'Comprender los límites de fondo de iOS';

  @override
  String get platformTutorialIosStep4Description =>
      'Las versiones anteriores a iOS 26 no permiten que las aplicaciones permanezcan en segundo plano como las aplicaciones de Android. El sistema proporciona a las aplicaciones un breve tiempo de ejecución solo en determinados momentos, como la actualización de la aplicación en segundo plano, las actualizaciones de ubicación o la reproducción de audio, y puede suspender tareas de ejecución prolongada. Recomendamos:\n• Mantenga Stroom en primer plano para tareas de larga duración.\n• Regrese a la aplicación periódicamente para actualizar su tiempo de fondo.\n• Active \"Notificaciones de finalización de tareas\" para tareas importantes.';

  @override
  String get platformTutorialIosStep5Title =>
      'Consejos en segundo plano mientras se ejecutan las tareas';

  @override
  String get platformTutorialIosStep5Description =>
      'iOS 26 y versiones posteriores admiten tareas persistentes en segundo plano. Las tareas generalmente continúan si cambias de aplicación o bloqueas la pantalla, aunque el sistema puede detenerlas cuando los recursos son escasos; El progreso aparece en la pantalla de bloqueo.\n\nLas versiones anteriores de iOS no admiten tareas persistentes en segundo plano. Regrese a la aplicación cada pocos minutos (5 a 10 minutos es una pauta; el sistema decide) para actualizar el tiempo en segundo plano y evitar la suspensión.\n\nEn todas las versiones, no deslices Stroom en el selector de aplicaciones; Al hacerlo, se detendrán inmediatamente todas las tareas en ejecución.';

  @override
  String get platformTutorialIosStep6Title =>
      'Mantenga la aplicación en primer plano';

  @override
  String get platformTutorialIosStep6Description =>
      'En versiones anteriores a iOS 26, las aplicaciones tienen un tiempo de fondo limitado. Para tareas de larga duración, mantenga Stroom en primer plano o vuelva a él periódicamente para extender ese tiempo.';

  @override
  String get platformTutorialWindowsStep1Title =>
      'Minimizar al cerrar la ventana.';

  @override
  String get platformTutorialWindowsStep1Description =>
      'De forma predeterminada, hacer clic en el botón de cerrar de la ventana minimiza Stroom en la bandeja del sistema (cerca del reloj) para que pueda seguir ejecutándose. Restaurarlo desde el icono de la bandeja o el menú \"Mostrar ventana principal\". No salga mientras se ejecutan las tareas. Para salir, use \"Salir de la aplicación por completo\" en la página \"Optimización de fondo\" o elija \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get platformTutorialWindowsStep2Title =>
      'Desactivar el ahorro de batería';

  @override
  String get platformTutorialWindowsStep2Description =>
      'Abra Configuración → Sistema → Encendido y suspensión y desactive Ahorro de batería. Alternativamente, configúrelo para que se encienda solo cuando la batería caiga por debajo del nivel elegido.';

  @override
  String get platformTutorialWindowsStep3Title =>
      'Permitir aplicaciones en segundo plano';

  @override
  String get platformTutorialWindowsStep3Description =>
      'Abra Configuración → Privacidad y seguridad → Aplicaciones en segundo plano, busque Stroom y asegúrese de que esté habilitado. En Windows 11, vaya a Configuración → Aplicaciones → Aplicaciones instaladas → Stroom → Opciones avanzadas → Permisos de aplicaciones en segundo plano y elija “Siempre”.';

  @override
  String get platformTutorialWindowsStep4Title =>
      'Desactivar el modo de suspensión (opcional)';

  @override
  String get platformTutorialWindowsStep4Description =>
      'Para mantener Stroom funcionando durante períodos prolongados, abra Configuración → Sistema → Encendido y configure “Suspender” en “Nunca” (solo cuando esté enchufado).';

  @override
  String get platformTutorialWindowsStep5Title => 'Agregar Stroom al inicio';

  @override
  String get platformTutorialWindowsStep5Description =>
      'Abra el Administrador de tareas (Ctrl+Shift+Esc) → Inicio, busque Stroom y haga clic derecho en \"Activar\". O abra Configuración → Aplicaciones → Inicio y active Stroom.';

  @override
  String get platformTutorialMacosStep1Title =>
      'Minimizar al cerrar la ventana.';

  @override
  String get platformTutorialMacosStep1Description =>
      'De forma predeterminada, cerrar la ventana mantiene Stroom ejecutándose en la barra de menú (arriba a la derecha de la pantalla). Haga clic en el icono de la barra de menú o elija \"Mostrar ventana principal\" para restaurarlo. No salga mientras se ejecutan las tareas. Para salir, use \"Salir de la aplicación por completo\" en la página \"Optimización de fondo\" o elija \"Salir de Stroom\" en el menú de la barra de menú.';

  @override
  String get platformTutorialMacosStep2Title => 'Permitir notificaciones';

  @override
  String get platformTutorialMacosStep2Description =>
      'Abra Configuración del sistema → Notificaciones → Stroom y active “Permitir notificaciones”. Recomendamos habilitar tanto los banners como el Centro de notificaciones.';

  @override
  String get platformTutorialMacosStep3Title =>
      'Desactivar el modo de bajo consumo (MacBook)';

  @override
  String get platformTutorialMacosStep3Description =>
      'Abra Configuración del sistema → Batería → Adaptador de corriente y desactive el “Modo de bajo consumo”. Este modo restringe la actividad en segundo plano.';

  @override
  String get platformTutorialMacosStep4Title => 'Mantén la aplicación activa';

  @override
  String get platformTutorialMacosStep4Description =>
      'macOS impone pocas restricciones a las aplicaciones en segundo plano. Para tareas de larga duración, deje abierta la ventana de Stroom. Evite el cierre forzado de la aplicación; cerrar la ventana es suficiente.';

  @override
  String get platformTutorialMacosStep5Title =>
      'Iniciar al iniciar sesión (opcional)';

  @override
  String get platformTutorialMacosStep5Description =>
      'Abra Configuración del sistema → General → Elementos de inicio de sesión y agregue Stroom para que se inicie automáticamente cuando se inicie su computadora.';

  @override
  String get platformTutorialLinuxStep1Title =>
      'Minimizar al cerrar la ventana.';

  @override
  String get platformTutorialLinuxStep1Description =>
      'De forma predeterminada, cerrar la ventana oculta Stroom en la bandeja del sistema (requiere un entorno de escritorio con soporte StatusNotifierItem y libayatana-appindicator3-dev en el momento de la compilación). Restaurarlo desde el menú de la bandeja usando \"Mostrar ventana principal\". No salga mientras se ejecutan las tareas. Para salir, use \"Salir de la aplicación por completo\" en la página \"Optimización de fondo\" o elija \"Salir de Stroom\" en el menú de la bandeja.';

  @override
  String get platformTutorialLinuxStep2Title =>
      'Configuración del entorno de escritorio';

  @override
  String get platformTutorialLinuxStep2Description =>
      'Dependiendo de su entorno de escritorio (GNOME, KDE, XFCE, etc.), abra Configuración del sistema → Aplicaciones, busque Stroom y asegúrese de que la actividad en segundo plano no esté restringida.';

  @override
  String get platformTutorialLinuxStep3Title =>
      'Utilice un servicio systemd (opcional)';

  @override
  String get platformTutorialLinuxStep3Description =>
      'Para un trabajo en segundo plano de larga duración, cree un servicio de usuario systemd. Cree un archivo stroom.service en ~/.config/systemd/user/ y configure ExecStart como el ejecutable de Stroom.';

  @override
  String get platformTutorialLinuxStep4Title => 'Desactivar el sueño';

  @override
  String get platformTutorialLinuxStep4Description =>
      'Para un servidor o escritorio que necesita funcionar durante mucho tiempo, configure HandleLidSwitch=ignore en /etc/systemd/logind.conf para evitar el modo de suspensión cuando se cierra la tapa.';

  @override
  String get platformTutorialLinuxStep5Title => 'Habilitar inicio automático';

  @override
  String get platformTutorialLinuxStep5Description =>
      'En GNOME, use Ajustes → Aplicaciones de inicio → Agregar Stroom. O cree un archivo stroom.desktop en ~/.config/autostart/.';

  @override
  String get platformTutorialWebStep1Title => 'Mantenga la pestaña abierta';

  @override
  String get platformTutorialWebStep1Description =>
      'Los navegadores web no admiten servicios en segundo plano. Mantenga abierta la pestaña Stroom mientras se ejecutan las tareas; cerrar la pestaña o actualizar la página los interrumpe inmediatamente.';

  @override
  String get platformTutorialWebStep2Title =>
      'Evitar que el navegador suspenda la pestaña';

  @override
  String get platformTutorialWebStep2Description =>
      'Los navegadores pueden congelar pestañas en segundo plano inactivas para ahorrar recursos. Mantenga la pestaña Stroom en primer plano mientras se ejecutan las tareas o interactúe con la página periódicamente para mantenerla activa.';

  @override
  String get browserNavigationFailed =>
      'Falló la navegación de la página; dirección restaurada';

  @override
  String get browserAddressHint => 'Introduzca una dirección web';

  @override
  String get browserUserScripts => 'Guiones de usuario';

  @override
  String get browserSwitchToMobile => 'Cambiar a vista móvil';

  @override
  String get browserSwitchToDesktop => 'Cambiar a la vista de escritorio';

  @override
  String get browserUaSwitchedDesktop =>
      'Cambiado al agente de usuario de escritorio';

  @override
  String get browserUaSwitchedMobile => 'Cambiado al agente de usuario móvil';

  @override
  String get browserCookieRetentionOnTooltip =>
      'Persistencia de cookies (activada)';

  @override
  String get browserCookieRetentionOffTooltip =>
      'Persistencia de cookies (desactivada)';

  @override
  String get browserCookiePersistenceEnabled =>
      'Persistencia de cookies habilitada';

  @override
  String get browserCookiePersistenceDisabled =>
      'Persistencia de cookies deshabilitada';

  @override
  String get browserSniffPanelHideTooltip => 'Ocultar panel de rastreo';

  @override
  String get browserSniffPanelShowTooltip => 'Mostrar panel de olfateo';

  @override
  String get browserAdd => 'Agregar';

  @override
  String get browserNoScripts =>
      'Aún no hay guiones. Toque \"Agregar\" para crear uno.';

  @override
  String get browserUnnamedScript => 'Guión sin título';

  @override
  String browserScriptMatchCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reglas coincidentes',
      one: '$count regla coincidente',
    );
    return '$_temp0';
  }

  @override
  String get browserScriptOriginManual => 'Agregado manualmente';

  @override
  String browserScriptVersion(Object version) {
    return '@versión $version';
  }

  @override
  String get browserScriptEnabled => 'Activado';

  @override
  String get browserScriptDisabled => 'Desactivado';

  @override
  String get browserScriptRuntimeError =>
      'Este script encontró un error de tiempo de ejecución. Comprueba su código y compatibilidad de páginas.';

  @override
  String get browserScriptDelete => 'Borrar';

  @override
  String get browserDeleteScriptTitle => '¿Eliminar guión?';

  @override
  String get browserDeleteScriptConfirmation =>
      'Este script se eliminará de este navegador. Esta acción no se puede deshacer.';

  @override
  String get browserEditScript => 'Editar guión';

  @override
  String get browserScriptName => 'Nombre del guión';

  @override
  String get browserScriptCode =>
      'Código de secuencia de comandos (JavaScript)';

  @override
  String get browserAddScriptMethod => 'Elija cómo agregar un script';

  @override
  String get browserImportFromUrl => 'Importar desde URL';

  @override
  String get browserEnterManually => 'Ingresar manualmente';

  @override
  String get browserScriptTrustWarningTitle =>
      'Importe sólo scripts en los que confíe';

  @override
  String get browserScriptTrustWarning =>
      'Agregue únicamente scripts en los que confíe o podrían filtrar datos. Los scripts pueden leer o modificar el contenido de la página web.';

  @override
  String get browserContinue => 'Continuar';

  @override
  String get browserManualUserscriptLabel => 'Guión de usuario de Tampermonkey';

  @override
  String get browserScriptImportUrl => 'URL del guión';

  @override
  String get browserScriptImportFetch => 'Obtener vista previa';

  @override
  String get browserScriptPreview => 'Vista previa del origen del script';

  @override
  String get browserScriptImportInvalidUrl => 'Ingrese una URL HTTPS válida.';

  @override
  String get browserScriptImportUnsupportedUrl =>
      'Utilice una URL Greasy Fork .user.js o una URL sin formato de GitHub.';

  @override
  String get browserScriptImportRedirectedUrl =>
      'La URL redirigida a una dirección no compatible o insegura.';

  @override
  String get browserScriptImportNotScript =>
      'La respuesta está vacía o no parece ser un script JavaScript.';

  @override
  String get browserScriptImportNetworkError =>
      'No se pudo recuperar el guión. Verifique la URL y su conexión.';

  @override
  String browserScriptImportHttpError(Object status) {
    return 'El servidor devolvió HTTP $status.';
  }

  @override
  String get browserCancel => 'Cancelar';

  @override
  String get browserSave => 'Guardar';

  @override
  String get browserCookiesConfirmClear => 'Confirmar compensación';

  @override
  String get browserCookiesConfirmClearAll =>
      '¿Borrar todas las cookies?\nEsta acción no se puede deshacer.';

  @override
  String get browserCookiesClear => 'Borrar cookies';

  @override
  String get browserCookiesCancel => 'Cancelar';

  @override
  String get browserCookiesClearedAll => 'Todas las cookies borradas';

  @override
  String get browserCookiesClearFailed =>
      'No se pudo borrar. Intentar otra vez.';

  @override
  String browserCookiesClearedDomain(Object domain) {
    return 'Todas las cookies para $domain borradas';
  }

  @override
  String browserCookiesClearDomainConfirm(Object domain) {
    return '¿Borrar todas las cookies para $domain?';
  }

  @override
  String get browserCookiesPageTitle => 'Gestión de datos del navegador';

  @override
  String get browserCookiesRetentionTitle => 'Mantener las cookies al salir';

  @override
  String get browserCookiesRetentionOn =>
      'Habilitado: las cookies se conservan al salir';

  @override
  String get browserCookiesRetentionOff =>
      'Deshabilitado: las cookies se borran al salir';

  @override
  String get browserCookiesClearAllTitle => 'Borrar todas las cookies';

  @override
  String get browserCookiesClearAllDescription =>
      'Eliminar todas las cookies guardadas del sitio web';

  @override
  String get browserCookiesEmptyTitle => 'Sin datos persistentes';

  @override
  String get browserCookiesEmptyDescription =>
      'Utilice el navegador integrado y habilite la persistencia de cookies para ver los datos guardados aquí.';

  @override
  String browserCookiesStoredCount(Object count) {
    return 'Cookies almacenadas ($count)';
  }

  @override
  String browserCookiesDomainCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cookies',
      one: '$count cookie',
    );
    return '$_temp0';
  }

  @override
  String get browserCookiesClearDomainTooltip =>
      'Borrar todas las cookies para este dominio';

  @override
  String get browserCookiesDeleteOneTooltip => 'Eliminar esta cookie';

  @override
  String get browserCookiesDeletedOne => 'Cookie eliminada';

  @override
  String get browserCookiesDeleteFailed =>
      'No se pudo eliminar. Intentar otra vez.';

  @override
  String get browserCookiesEmptyValue => '(valor vacío)';

  @override
  String get platformTutorialPageTitle => 'Tutoriales de plataforma';

  @override
  String get browserRecoveryOpenPage => 'Abrir página de recuperación';

  @override
  String galleryUnsupportedPreview(String format) {
    return 'La vista previa no es compatible con archivos .$format';
  }

  @override
  String galleryCameraFailed(String error) {
    return 'No se pudo tomar una foto: $error';
  }

  @override
  String get galleryPhotoSaved => 'Foto guardada';

  @override
  String galleryUnsupportedImportFormat(String format) {
    return 'Formato no compatible omitido: $format';
  }

  @override
  String galleryImportImagesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron # imágenes',
      one: 'Se importó # imagen',
    );
    return '$_temp0';
  }

  @override
  String galleryImportVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se importaron # videos',
      one: 'Se importó # video',
    );
    return '$_temp0';
  }

  @override
  String galleryImportFailed(String error) {
    return 'Error de importación: $error';
  }

  @override
  String get galleryFileReadFailed =>
      'No se pudieron leer los datos del archivo';

  @override
  String get galleryExportImageTitle => 'Exportar imagen';

  @override
  String get galleryExportVideoTitle => 'Exportar vídeo';

  @override
  String galleryExportedTo(String path) {
    return 'Exportado a: $path';
  }

  @override
  String galleryExportFailed(String error) {
    return 'Error al exportar: $error';
  }

  @override
  String get galleryChooseExportDirectory =>
      'Elija el directorio de exportación';

  @override
  String galleryExportedFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se exportaron # archivos',
      one: 'Se exportó # archivo',
    );
    return '$_temp0';
  }

  @override
  String get galleryFolderExportTitle => 'Exportar carpeta';

  @override
  String get galleryWebFolderExportInfo =>
      'El navegador no puede seleccionar un directorio de exportación. Se descargará un archivo ZIP que conserva la estructura de carpetas.';

  @override
  String get galleryDownloadZip => 'Descargar archivo ZIP';

  @override
  String get galleryExportImageFolderTitle => 'Exportar carpeta de imágenes';

  @override
  String get galleryExportVideoFolderTitle => 'Exportar carpeta de vídeo';

  @override
  String get galleryImagePageTitle => 'Galería';

  @override
  String get galleryVideoPageTitle => 'Vídeos';

  @override
  String get galleryTakePhoto => 'tomar foto';

  @override
  String get galleryRecordVideo => 'Registro';

  @override
  String get galleryImport => 'Importar';

  @override
  String get galleryExportToLocal => 'Exportar a local';

  @override
  String get galleryPlayVideo => 'Jugar';

  @override
  String galleryCopyFailed(String error) {
    return 'Copia fallida: $error';
  }

  @override
  String get galleryVideoSaved => 'Vídeo guardado';

  @override
  String galleryVideoRecordFailed(String error) {
    return 'Error de grabación: $error';
  }

  @override
  String get galleryVideoLoadFailed => 'No se pudo cargar el video';

  @override
  String get imageEditorSaveImageTitle => 'Salvar el imagen';

  @override
  String get imageEditorSaveImagePrompt => 'Elija cómo guardar la imagen:';

  @override
  String get imageEditorOverwrite => 'Exagerar';

  @override
  String get imageEditorSaveAs => 'Guardar como';

  @override
  String get imageEditorSavePhotoTitle => 'guardar foto';

  @override
  String get imageEditorSavePhotoPrompt => '¿Guardar esta foto?';

  @override
  String get imageEditorDiscard => 'Desechar';

  @override
  String get imageEditorDoneLoading => 'Generando imagen. Espere por favor…';

  @override
  String imageEditorQuickTitle(String fileName) {
    return 'Edición rápida – $fileName';
  }

  @override
  String get imageEditorNotReady =>
      'El editor no está listo. Inténtelo de nuevo en un momento.';

  @override
  String imageEditorProcessingFailed(String error) {
    return 'No se pudo procesar la imagen: $error';
  }

  @override
  String get imageEditorLoadFailed => 'No se pudo cargar la imagen';

  @override
  String get imageEditorProcessing =>
      'Procesamiento de imagen. Espere por favor…';

  @override
  String get imageEditorRotateLeft => 'Girar a la izquierda';

  @override
  String get imageEditorRotateRight => 'Girar a la derecha';

  @override
  String get imageEditorFlip => 'Voltear';

  @override
  String get imageEditorCrop => 'Cultivo';

  @override
  String get imageViewerImageSavedAsCopy => 'Imagen guardada como copia';

  @override
  String get imageViewerImageUpdated => 'Imagen actualizada';

  @override
  String imageViewerSaveFailed(String error) {
    return 'No se pudo guardar la imagen: $error';
  }

  @override
  String get imageViewerInvalidIndex => 'Índice de imagen no válido';

  @override
  String get galleryExportImageArchiveFileName => 'exportar-imagen.zip';

  @override
  String get galleryExportVideoArchiveFileName => 'exportar-video.zip';

  @override
  String get galleryExportImageFolderArchiveFileName =>
      'carpeta-imagen-exportar.zip';

  @override
  String get galleryExportVideoFolderArchiveFileName =>
      'carpeta-de-video-exportación.zip';

  @override
  String get catCatchPageTitle => 'Descargador de recursos web';

  @override
  String get catCatchAddTask => 'Agregar tarea';

  @override
  String get catCatchOpenBrowser => 'Navegador incorporado';

  @override
  String get catCatchEmptyState => 'Aún no hay tareas de descarga';

  @override
  String get catCatchEmptyStateHint =>
      'Toca + en la parte superior derecha para agregar una tarea de descarga';

  @override
  String get catCatchInvalidCapturedUrl => 'La URL capturada no es válida.';

  @override
  String catCatchCapturedFromBrowser(String url) {
    return 'Capturado desde el navegador: $url';
  }

  @override
  String get catCatchEnterValidUrl => 'Introduce al menos una URL válida';

  @override
  String get catCatchTaskAdded => 'Tarea agregada';

  @override
  String catCatchTasksAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas añadidas',
      one: '$count tarea añadida',
    );
    return '$_temp0';
  }

  @override
  String get catCatchViewTaskList => 'Ver lista de tareas';

  @override
  String get catCatchUrlHint =>
      'Ingrese la URL de una página web de video/audio';

  @override
  String get catCatchDeleteTask => 'Eliminar esta tarea';

  @override
  String get catCatchHour => 'Horas';

  @override
  String get catCatchMinute => 'Minutos';

  @override
  String get catCatchSecond => 'Artículos de segunda clase';

  @override
  String get catCatchDurationPreview => 'Avance:';

  @override
  String get catCatchDurationFormat => 'h:min:seg';

  @override
  String get catCatchDurationFilterHint =>
      'Opcional: filtre los recursos de vídeo por duración. Déjelo en blanco para mostrar todos los recursos para su selección.';

  @override
  String get catCatchVideoSaveTo => 'Guardar vídeo en';

  @override
  String get catCatchAudioSaveTo => 'Guardar audio en';

  @override
  String catCatchTaskCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tareas añadidas',
      one: '$count tarea añadida',
    );
    return '$_temp0';
  }

  @override
  String get catCatchStartAnalysis => 'Analizar';

  @override
  String get catCatchVideoFolderTitle => 'Carpeta para guardar vídeos';

  @override
  String get catCatchAudioFolderTitle => 'Carpeta para guardar audio';

  @override
  String get catCatchRootFolder => 'Carpeta raíz';

  @override
  String connectivityTestTitle(String title) {
    return '$title · Prueba de conectividad';
  }

  @override
  String get connectivityTestJsonLabel => 'Contenido de prueba (JSON)';

  @override
  String get connectivityTestJsonHelp =>
      'Puede ejecutar o guardar los cambios directamente. MCP utiliza herramientas/listas de solo lectura; las herramientas de búsqueda pueden cambiar la consulta/el recuento; Todo es de sólo lectura de forma predeterminada.';

  @override
  String connectivityTestSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get connectivityTestSaved => 'Contenido de prueba guardado';

  @override
  String get connectivityTestClose => 'Cerrar';

  @override
  String get connectivityTestSaveContent => 'Guardar contenido';

  @override
  String get connectivityTestTesting => 'Pruebas…';

  @override
  String get connectivityTestRun => 'Ejecutar prueba';

  @override
  String get connectivityTestFailedSummary => 'No se pudo completar la prueba';

  @override
  String connectivityTestDurationSeconds(String seconds) {
    return '$seconds seg.';
  }

  @override
  String connectivityTestDurationMilliseconds(int milliseconds) {
    return '$milliseconds ms';
  }

  @override
  String get messageSearchTitle => 'Buscar mensajes';

  @override
  String get messageSearchHint =>
      'Buscar mensajes en todas las conversaciones...';

  @override
  String get messageSearchInitialState =>
      'Escriba una palabra clave para buscar mensajes en todas las conversaciones.';

  @override
  String get messageSearchEmptyState =>
      'No se encontraron mensajes coincidentes';

  @override
  String get messageSearchNewConversation => 'Nueva conversación';

  @override
  String messageSearchMatchCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coincidencias',
      one: '$count coincidencia',
    );
    return '$_temp0';
  }

  @override
  String get filesTabText => 'Texto';

  @override
  String get filesTabAudio => 'Audio';

  @override
  String get filesTabImages => 'Imágenes';

  @override
  String get filesTabVideos => 'Vídeos';

  @override
  String get filesReorderTabs => 'Reordenar pestañas';

  @override
  String get filesReorderCancel => 'Cancelar';

  @override
  String get filesReorderDone => 'Hecho';

  @override
  String get bgTaskCancelled => 'Cancelado';

  @override
  String bgTaskAsrError(String details) {
    return 'Error en la transcripción de voz: $details';
  }

  @override
  String bgTaskAsrSaveError(String details) {
    return 'Error al guardar la transcripción de voz: $details';
  }

  @override
  String bgTaskOcrError(String details) {
    return 'Error de OCR: $details';
  }

  @override
  String bgTaskOcrSaveError(String details) {
    return 'Error al guardar los resultados de OCR: $details';
  }

  @override
  String bgTaskOcrIncompleteError(String details) {
    return 'El resultado del OCR está incompleto: $details';
  }

  @override
  String get bgTaskOcrIncompleteFallback =>
      'Algunas páginas de OCR no se completaron';

  @override
  String bgTaskProgressMetrics(
    String phaseElapsedMs,
    String completedRequests,
    String completedChunks,
    String chunkCount,
  ) {
    return '· fase $phaseElapsedMs ms · solicitudes $completedRequests · fragmentos $completedChunks/$chunkCount completados';
  }

  @override
  String bgTaskAsrUploadProgress(
    String chunk,
    String percent,
    String bytes,
    String metrics,
  ) {
    return 'Subiendo audio$chunk $percent% · $bytes bytes$metrics';
  }

  @override
  String bgTaskAsrUploadChunk(String chunk, String metrics) {
    return 'Subiendo audio$chunk$metrics';
  }

  @override
  String bgTaskAsrChunk(String index, String count) {
    return '(fragmento $index/$count)';
  }

  @override
  String bgTaskAsrTranscribing(String metrics) {
    return 'Transcribiendo$metrics';
  }

  @override
  String bgTaskAsrTranscribingChunk(
    String index,
    String count,
    String metrics,
  ) {
    return 'Transcripción (fragmento $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceivingChunk(String index, String count, String metrics) {
    return 'Transcribiendo (recibiendo fragmento $index/$count)$metrics';
  }

  @override
  String bgTaskAsrReceiveProgress(String percent, String metrics) {
    return 'Recibiendo resultado $percent%$metrics';
  }

  @override
  String get bgTaskAsrReceive => 'Recibiendo resultado';

  @override
  String bgTaskAsrCompletedChunks(String index, String count, String metrics) {
    return 'Transcripción (fragmentos $index/$count completados)$metrics';
  }

  @override
  String bgTaskAsrChunkReturned(String index, String count, String metrics) {
    return 'Transcripción (fragmento $index/$count devuelto)$metrics';
  }

  @override
  String bgTaskOcrUploadPageProgress(
    String index,
    String total,
    String percent,
  ) {
    return 'Imagen $index/$total $percent%';
  }

  @override
  String bgTaskOcrUploadPagesProgress(String details) {
    return 'Subiendo $details';
  }

  @override
  String bgTaskOcrUploadProgress(String percent) {
    return 'Subiendo imágenes $percent%';
  }

  @override
  String bgTaskAsrCheckpointUncertain(String details) {
    return 'No se pudo guardar el punto de control de recuperación de ASR; el resultado de la solicitud es incierto y la tarea se detuvo: $details';
  }

  @override
  String bgTaskAsrCheckpointNotSent(String details) {
    return 'No se pudo guardar el punto de control de recuperación de ASR; este fragmento no se envió y se puede volver a intentar después de arreglar el almacenamiento local: $details';
  }

  @override
  String bgTaskAsrCheckpointCancelled(String details) {
    return 'El estado del fragmento ASR no se pudo guardar antes de la cancelación; El resultado de este fragmento sigue siendo incierto: $details';
  }

  @override
  String bgTaskAsrRetryAudioSaveError(String details) {
    return 'No se pudo guardar el audio del reintento de ASR; la tarea no fue enviada: $details';
  }

  @override
  String get bgTaskAsrBatchAudioSaveError =>
      'No se pudo guardar otro archivo de audio; el envío fue cancelado';

  @override
  String bgTaskOcrResultIncomplete(String finishReason) {
    return 'El OCR devolvió un resultado incompleto (finish_reason=$finishReason)';
  }

  @override
  String ocrResultPageHeading(String index) {
    return 'Imagen $index';
  }

  @override
  String ocrResultPageHeadingWithName(String index, String name) {
    return 'Imagen $index: $name';
  }

  @override
  String get ocrPartialResultSuffix => '(resultado parcial)';

  @override
  String bgTaskOcrPagesIncomplete(String details) {
    return 'Algunas imágenes no fueron reconocidas completamente: $details';
  }

  @override
  String bgTaskOcrPageIncomplete(String index) {
    return 'Imagen $index: resultado incompleto';
  }

  @override
  String bgTaskOcrPageFailed(String index) {
    return 'Imagen $index: error de reconocimiento';
  }

  @override
  String get bgTaskOcrPageFailureSeparator => ';';

  @override
  String get bgTaskInterruptedOnRestart =>
      'Interrumpido cuando se reinició la aplicación.';

  @override
  String get bgTaskOcrErrorDetailsHidden =>
      'Los detalles del error de OCR estaban ocultos';

  @override
  String get bgTaskErrorDetailsHidden =>
      'Los detalles del error estaban ocultos';

  @override
  String get notificationBannerTaskCompletedHeading => 'Tarea completada';

  @override
  String get notificationBannerTaskFailedHeading => 'Tarea fallida';

  @override
  String notificationTaskCompletedTitle(String typeLabel) {
    return 'Tarea completada: $typeLabel';
  }

  @override
  String notificationTaskFailedTitle(String typeLabel) {
    return 'Tarea fallida: $typeLabel';
  }

  @override
  String notificationTaskCompletedBody(String title) {
    return '$title completado';
  }

  @override
  String notificationTaskFailedBody(String title, String error) {
    return '$title falló: $error';
  }

  @override
  String get notificationUnknownError => 'Error desconocido';

  @override
  String get desktopTrayTooltip =>
      'Stroom se está ejecutando en segundo plano.';

  @override
  String get desktopTrayOpen => 'Baño abierto';

  @override
  String get desktopTrayShowMainWindow => 'Mostrar ventana principal';

  @override
  String get desktopTrayQuitStroom => 'Salir de Stroom';

  @override
  String get providerPresetExaDescription =>
      'Busque en la web, extraiga el contenido de la página y respalde la investigación en profundidad a través de Exa MCP, con búsqueda semántica y de palabras clave.';

  @override
  String get providerPresetExaApiKeyHint =>
      'Obtenga una clave API del sitio web de Exa.';

  @override
  String get providerPresetTavilyDescription =>
      'Un motor de búsqueda nativo de IA para búsquedas web en tiempo real optimizado para modelos de lenguaje grandes.';

  @override
  String get providerPresetTavilyApiKeyHint =>
      'Obtenga una clave API de Tavily. Admite ?tavilyApiKey= o una autorización: encabezado portador.';

  @override
  String get providerPresetJinaDescription =>
      'Un servicio de IA multimodal para extraer contenido web, generar incrustaciones y recuperar resultados de búsqueda.';

  @override
  String get providerPresetJinaApiKeyHint =>
      'Obtenga una clave API de Jina AI (token de portador) desde su sitio web.';

  @override
  String get providerPresetFirecrawlDescription =>
      'Un servicio de extracción y rastreo web que convierte páginas en Markdown limpio o datos estructurados.';

  @override
  String get providerPresetFirecrawlApiKeyHint =>
      'Obtenga una clave API de Firecrawl o pruébela sin clave con los límites del nivel gratuito.';

  @override
  String get providerPresetZhipuDescription =>
      'Servicio MCP de lector web de Zhipu AI para buscar y comprender páginas web.';

  @override
  String get providerPresetZhipuApiKeyHint =>
      'Obtenga una clave API (token de portador) de la plataforma abierta Zhipu AI.';

  @override
  String get providerPresetBraveSearchDescription =>
      'Un motor de búsqueda independiente centrado en la privacidad con resultados web de alta calidad.';

  @override
  String get providerPresetBraveSearchApiKeyHint =>
      'Obtenga una clave API del sitio web de Brave Search.';

  @override
  String get providerPresetBochaDescription =>
      'La búsqueda web de Bocha AI proporciona resultados de búsqueda inteligentes para páginas en idioma chino.';

  @override
  String get providerPresetBochaApiKeyHint =>
      'Obtenga una clave API (token de portador) de la plataforma abierta Bocha AI.';

  @override
  String get providerPresetQueritDescription =>
      'La búsqueda de Querit AI ofrece búsqueda inteligente y descubrimiento de contenido.';

  @override
  String get providerPresetQueritApiKeyHint =>
      'Obtenga una clave API (token de portador) del sitio web de Querit.';

  @override
  String get providerPresetSearxngDescription =>
      'Un metabuscador autohospedado que agrega fuentes de búsqueda centrándose en la privacidad.';

  @override
  String get providerPresetSearxngApiKeyHint =>
      'Configure la URL de su instancia de SearXNG (por ejemplo, http://su-instancia:8080); una clave API es opcional.';

  @override
  String ttsErrorSynthesisFailed(String details) {
    return 'La síntesis TTS falló: $details';
  }

  @override
  String ttsErrorOriginalError(String details) {
    return 'Error original: $details';
  }

  @override
  String get ttsErrorNetworkConnectionTimeout =>
      'Se agotó el tiempo de conexión de red. Verifique su red o dirección API.';

  @override
  String get ttsErrorServerResponseTimeout =>
      'Se agotó el tiempo de respuesta del servidor. Vuelve a intentarlo más tarde.';

  @override
  String ttsErrorConnectionFailed(String details) {
    return 'No se puede conectar al servidor ($details)';
  }

  @override
  String ttsErrorWebConnectionGuidance(String details) {
    return 'No se puede conectar con el servidor. Causas comunes en la aplicación web: restricciones de CORS o una dirección API incorrecta. $details';
  }

  @override
  String ttsErrorApiResponse(String body, String status) {
    return 'La API devolvió un error (HTTP $status$body)';
  }

  @override
  String ttsErrorConnectTimeout(String details) {
    return 'Se agotó el tiempo de conexión. Comprueba tu red$details';
  }

  @override
  String ttsErrorReceiveTimeout(String details) {
    return 'Recibir tiempo de espera agotado; el servidor responde lentamente$details';
  }

  @override
  String ttsErrorInvalidApiKey(String body, String details, String status) {
    return 'La clave API no es válida o se ha denegado el permiso (HTTP $status): $body$details';
  }

  @override
  String ttsErrorTooManyRequests(String details, String status) {
    return 'Demasiadas solicitudes; Inténtelo de nuevo más tarde (HTTP $status)$details';
  }

  @override
  String ttsErrorEndpointNotFound(String body, String details, String status) {
    return 'Punto final API no encontrado (HTTP $status): $body\nCompruebe que la URL base de la API sea correcta$details';
  }

  @override
  String ttsErrorServerInternal(String body, String details, String status) {
    return 'Error interno del servidor (HTTP $status): $body$details';
  }

  @override
  String ttsErrorServerResponse(String body, String details, String status) {
    return 'El servidor devolvió un error (HTTP $status): $body$details';
  }

  @override
  String ttsErrorRequestCancelled(String details) {
    return 'Solicitud cancelada$details';
  }

  @override
  String ttsErrorWebNetworkGuidance(String details) {
    return 'No se puede conectar con el servidor. Causas comunes en la aplicación web: restricciones de CORS o una dirección API incorrecta. Compruebe que la dirección API del proveedor sea correcta y que el servidor permita solicitudes de origen cruzado.$details';
  }

  @override
  String ttsErrorNetwork(String details) {
    return 'Error de red: $details';
  }

  @override
  String get ttsErrorUnknownNetwork => 'Error de red desconocido';

  @override
  String get ttsErrorNoResponseBody => 'Sin cuerpo de respuesta';

  @override
  String ttsErrorStreamingSynthesisFailed(String details) {
    return 'Error en la síntesis de streaming: $details';
  }

  @override
  String get mermaidEditorTitle => 'Editor de gráficos de sirena';

  @override
  String get mermaidEditorModeEdit => 'Editar';

  @override
  String get mermaidEditorModeSplit => 'Editar + Vista previa';

  @override
  String get mermaidEditorModePreview => 'Avance';

  @override
  String get mermaidEditorSwitchViewMode => 'Cambiar modo de vista';

  @override
  String get mermaidEditorSaveToTextStorage =>
      'Guardar en almacenamiento de texto';

  @override
  String get mermaidEditorEmptyChart =>
      'El contenido del gráfico está vacío y no se puede guardar.';

  @override
  String get mermaidEditorSaveChartTitle => 'Guardar gráfico';

  @override
  String get mermaidEditorSaveFolderGuidance =>
      'Elija o cree una carpeta para guardar el archivo del gráfico .mmd';

  @override
  String get mermaidEditorFileNameHint =>
      'Ingrese un nombre de archivo (.mmd agregado automáticamente)';

  @override
  String get mermaidEditorEmptyFileName =>
      'El nombre del archivo no puede estar vacío';

  @override
  String mermaidEditorSavedToTextStorage(String path) {
    return 'Guardado en almacenamiento de texto: $path';
  }

  @override
  String mermaidEditorSaveFailed(String error) {
    return 'Error al guardar: $error';
  }

  @override
  String get mermaidEditorSwapPreviewAndEditor =>
      'Intercambiar paneles de vista previa y editor';

  @override
  String get mermaidEditorCodeLabel => 'código sirena';

  @override
  String get mermaidEditorCodeHint => 'Introduce el código de sirena...';

  @override
  String get mermaidEditorSplitCodeLabel => 'Código';

  @override
  String sseConnectionFailedWithStatus(int statusCode, String statusText) {
    return 'La conexión SSE falló (HTTP $statusCode: $statusText)';
  }

  @override
  String sseConnectionFailedWithoutStatusText(int statusCode) {
    return 'La conexión SSE falló (HTTP $statusCode)';
  }

  @override
  String get sseConnectionUnavailable =>
      'Error en la conexión SSE: no se puede conectar al servidor';

  @override
  String sseHttpRequestFailed(int statusCode, String statusText) {
    return 'La solicitud HTTP falló (HTTP $statusCode: $statusText)';
  }

  @override
  String get sseRequestFailed => 'Solicitud fallida';

  @override
  String get sseNetworkRequestFailed => 'Error en la solicitud de red';

  @override
  String sseNetworkRequestFailedWithStatus(int statusCode, String statusText) {
    return 'Error en la solicitud de red (HTTP $statusCode: $statusText)';
  }

  @override
  String sseNetworkRequestFailedWithoutStatusText(int statusCode) {
    return 'Error en la solicitud de red (HTTP $statusCode)';
  }

  @override
  String get sseNetworkConnectionUnavailable =>
      'Error en la solicitud de red: no se puede conectar al servidor';

  @override
  String get sseRequestCancelled => 'Solicitud cancelada';

  @override
  String get startupSafetyTitle => 'Protección de seguridad de datos';

  @override
  String get startupSafetyExportButton => 'Exportar datos';

  @override
  String get startupSafetyExitButton => 'Salir de la aplicación';

  @override
  String get startupSafetyUpdateButton => 'Actualizar aplicación';

  @override
  String get startupSafetyCheckingUpdates => 'Buscando actualizaciones...';

  @override
  String get startupSafetyUpToDate => 'Estás al día';

  @override
  String startupSafetyNewerDataVersion(String version) {
    return 'Estos datos fueron creados por una versión más reciente de la aplicación ($version).\n\nEsta versión de la aplicación no puede leer los datos de forma segura. Instale la última versión para continuar. Tus datos no han sido modificados.';
  }

  @override
  String get startupSafetyStatusUnreadable =>
      'No se pudo confirmar el estado de seguridad de los datos (el marcador de estado no se pudo leer o no era válido).\n\nPara evitar sobrescribir un posible estado congelado, se ha bloqueado el inicio sin reparar datos ni migrar formatos. Primero exporte su archivo de datos, luego salga de la aplicación, repare el marcador de estado y vuelva a intentarlo.';

  @override
  String startupSafetyMigrationFailedNoChanges(String part) {
    return 'Error en la migración del formato de datos ($part).\n\nPara proteger sus datos, no se realizaron cambios. Vuelva a la versión anterior de la aplicación o espere una versión reparada antes de actualizar.';
  }

  @override
  String startupSafetyMigrationFailedRestored(String part) {
    return 'Error en la migración del formato de datos ($part).\n\nSus datos fueron restaurados a su estado previo a la migración. Para protegerla, regrese a la versión anterior de la aplicación o espere una versión reparada antes de actualizar.';
  }

  @override
  String get startupSafetyDataCorrupted =>
      'Los datos están dañados y no se pueden reparar automáticamente.\n\nLa aplicación se ha congelado para evitar daños mayores. Exporte su archivo de datos, luego impórtelo manualmente o reinstálelo.';

  @override
  String get startupSafetyPreferencesUnavailable =>
      'La aplicación no pudo leer las preferencias requeridas para las comprobaciones de inicio, por lo que el inicio se bloqueó para proteger sus datos.\n\nVerifique el espacio de almacenamiento o los permisos, luego vuelva a abrir la aplicación.';

  @override
  String get startupSafetyValidationUnavailable =>
      'La aplicación no pudo completar la verificación de seguridad de los datos de inicio, por lo que se bloqueó el inicio para proteger sus datos.\n\nVerifique la configuración del navegador y luego vuelva a abrir la aplicación.';

  @override
  String startupSafetyCheckFailed(String detail) {
    return 'Error en la comprobación de inicio: $detail';
  }

  @override
  String get startupSafetyStatusUnreadableAfterChecks =>
      'El estado de seguridad de los datos no se pudo confirmar después de las comprobaciones de inicio (el marcador de estado no se pudo leer o no era válido).\n\nEl inicio se detuvo para evitar realizar más cambios en los datos. Exporte su archivo de datos, salga de la aplicación, repare el marcador de estado y vuelva a intentarlo.';

  @override
  String get catCatchConnectionTimeout =>
      'Se agotó el tiempo de conexión. Verifique el estado de su red o servidor.';

  @override
  String get catCatchSendTimeout =>
      'Se agotó el tiempo de espera de la solicitud durante el envío.';

  @override
  String get catCatchReceiveTimeout =>
      'Se agotó el tiempo de respuesta porque el servidor está tardando demasiado.';

  @override
  String get catCatchCannotConnect => 'No se pudo conectar al servidor.';

  @override
  String get catCatchConnectionError =>
      'No se pudo conectar al servidor. Compruebe que la URL sea correcta.';

  @override
  String get catCatchBadCertificate =>
      'No se pudo verificar el certificado del servidor.';

  @override
  String catCatchBadResponse(int statusCode) {
    return 'El servidor devolvió un error (HTTP $statusCode)';
  }

  @override
  String get catCatchRequestCancelled => 'La solicitud fue cancelada.';

  @override
  String catCatchNetworkError(String message) {
    return 'Error de red: $message';
  }

  @override
  String get catCatchUnknownError => 'Error desconocido';

  @override
  String catCatchOriginalError(String message) {
    return 'Error original: $message';
  }

  @override
  String get catCatchWebDownloadHint =>
      'Los navegadores web no pueden descargar archivos multimedia directamente.';

  @override
  String get catCatchWebInstallExtension =>
      'Instale la extensión del navegador CatCatch y vuelva a intentarlo.';

  @override
  String get catCatchWebAuthorAttribution =>
      'Autor: 笨笨猫 (xifangczy). Gratis y de código abierto.';

  @override
  String get catCatchWebOfficialWarning =>
      'Asegúrate de que sea la versión del autor; Evite las versiones pagas o de imitación.';

  @override
  String get catCatchWebGitHubAddress =>
      'GitHub: https://github.com/xifangczy/cat-catch';

  @override
  String get catCatchLoginRequired =>
      'Esta función requiere una cuenta iniciada. Inicie sesión usando el navegador en la esquina superior derecha.';

  @override
  String get catCatchNoUsableMedia =>
      'No se encontró ningún recurso multimedia utilizable. Verifique la URL y asegúrese de que se pueda acceder al sitio web.';

  @override
  String get catCatchRedownloadFileMissing =>
      'La descarga falló porque falta el archivo descargado.';

  @override
  String get catCatchRedownloadPathEmpty =>
      'La descarga falló porque la ruta del archivo descargado está vacía.';

  @override
  String get catCatchWebBrowserRequired =>
      'Esta página no puede exponer sus recursos sin un entorno de navegador. Intente utilizar la función en un dispositivo móvil o de escritorio, o pegue una URL directa de un archivo de video o audio.';

  @override
  String get catCatchPlaylistNoSegments =>
      'La lista de reproducción no tiene segmentos descargables.';

  @override
  String get catCatchDownloadedSourceMissing =>
      'Falta el archivo fuente descargado. Por favor descárguelo nuevamente.';

  @override
  String get appLogPageTitle => 'Registros de aplicaciones';

  @override
  String get appLogRefresh => 'Refrescar';

  @override
  String get appLogCleanupOldLogs => 'Limpiar registros viejos';

  @override
  String get appLogCleanupDone => 'Se limpiaron los troncos viejos.';

  @override
  String appLogRetentionNotice(int days) {
    return 'Retención de registros: solo se conservan los días $days más recientes. Los registros con más de $days días se limpian automáticamente.';
  }

  @override
  String get appLogWebUnsupported =>
      'Los registros locales no son compatibles con la web';

  @override
  String get appLogNoFiles => 'Aún no hay archivos de registro';

  @override
  String appLogAutoRefresh(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Actualizando automáticamente (intentos $count)...',
      one: 'Actualizando automáticamente (intento $count)...',
    );
    return '$_temp0';
  }

  @override
  String get appLogWillBeCreated =>
      'Los registros se generan mientras la aplicación se está ejecutando.';

  @override
  String get appLogExport => 'Exportar';

  @override
  String get appLogDelete => 'Borrar';

  @override
  String get appLogConfirmDeleteTitle => 'Confirmar eliminación';

  @override
  String appLogConfirmDeleteMessage(String fileName) {
    return '¿Eliminar el archivo de registro \"$fileName\"?';
  }

  @override
  String get appLogCancel => 'Cancelar';

  @override
  String appLogLoadFilesError(Object error) {
    return 'No se pudo cargar la lista de archivos de registro: $error';
  }

  @override
  String appLogReadFileUnreadable(String fileName) {
    return 'El archivo de registro \"$fileName\" existe pero no se pudo leer; puede estar corrupto';
  }

  @override
  String appLogReadFileMissing(String fileName) {
    return 'No se encontró el archivo de registro \"$fileName\"; puede que lo hayan limpiado';
  }

  @override
  String appLogReadFileError(Object error) {
    return 'No se pudo leer el archivo de registro: $error';
  }

  @override
  String appLogDeleteDone(String fileName) {
    return 'Eliminado: $fileName';
  }

  @override
  String appLogDeleteError(Object error) {
    return 'Error al eliminar: $error';
  }

  @override
  String appLogExportMissing(String fileName) {
    return 'No se encontró el archivo de registro \"$fileName\"';
  }

  @override
  String appLogPathCopied(String filePath) {
    return 'Ruta copiada: $filePath';
  }

  @override
  String appLogExportError(Object error) {
    return 'Error al exportar: $error';
  }

  @override
  String appLogLineCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count líneas',
      one: '$count línea',
    );
    return '$_temp0';
  }

  @override
  String get appLogCopyAll => 'Copiar todo';

  @override
  String get appLogStructuredView => 'Vista estructurada';

  @override
  String get appLogRawView => 'Vista cruda';

  @override
  String appLogCopyError(Object error) {
    return 'Copia fallida: $error';
  }

  @override
  String get appLogCopyDone => 'Copié todo el contenido del registro.';

  @override
  String get iosContinuedTaskTitle => 'Tarea en segundo plano';

  @override
  String get mermaidCatalogTypeFlowchart => 'Diagrama de flujo';

  @override
  String get mermaidCatalogDescriptionFlowchart =>
      'Diagrama de flujo: muestra pasos, ramas y bucles';

  @override
  String get mermaidCatalogTypeSequenceDiagram => 'Diagrama de secuencia';

  @override
  String get mermaidCatalogDescriptionSequenceDiagram =>
      'Diagrama de secuencia: muestra las interacciones entre los participantes.';

  @override
  String get mermaidCatalogTypeClassDiagram => 'diagrama de clases';

  @override
  String get mermaidCatalogDescriptionClassDiagram =>
      'Diagrama de clases: muestra las relaciones entre los atributos y métodos de la clase.';

  @override
  String get mermaidCatalogTypeStateDiagram => 'diagrama de estado';

  @override
  String get mermaidCatalogDescriptionStateDiagram =>
      'Diagrama de estado: muestra transiciones de estado';

  @override
  String get mermaidCatalogTypeErDiagram => 'diagrama ER';

  @override
  String get mermaidCatalogDescriptionErDiagram =>
      'Diagrama ER: muestra las relaciones entre entidades';

  @override
  String get mermaidCatalogTypeGantt => 'diagrama de Gantt';

  @override
  String get mermaidCatalogDescriptionGantt =>
      'Diagrama de Gantt: muestra un cronograma del proyecto';

  @override
  String get mermaidCatalogTypePie => 'gráfico circular';

  @override
  String get mermaidCatalogDescriptionPie =>
      'Gráfico circular: muestra datos proporcionales';

  @override
  String get mermaidCatalogTypeJourney => 'Viaje del usuario';

  @override
  String get mermaidCatalogDescriptionJourney =>
      'Viaje del usuario: muestra el flujo de la experiencia del usuario';

  @override
  String get mermaidCatalogTypeGitGraph => 'gráfico de git';

  @override
  String get mermaidCatalogDescriptionGitGraph =>
      'Gráfico de Git: muestra ramas y confirmaciones';

  @override
  String get mermaidCatalogTypeMindmap => 'mapa mental';

  @override
  String get mermaidCatalogDescriptionMindmap =>
      'Mapa mental: muestra una jerarquía';

  @override
  String get mermaidCatalogTypeTimeline => 'Línea de tiempo';

  @override
  String get mermaidCatalogDescriptionTimeline =>
      'Línea de tiempo: muestra eventos en orden cronológico';

  @override
  String get mermaidCatalogTypeBlock => 'diagrama de bloques';

  @override
  String get mermaidCatalogDescriptionBlock =>
      'Diagrama de bloques: muestra el diseño y las relaciones de los bloques';

  @override
  String get mermaidCatalogTypeRequirement => 'Diagrama de requisitos';

  @override
  String get mermaidCatalogDescriptionRequirement =>
      'Diagrama de requisitos: muestra los requisitos y las relaciones de implementación.';

  @override
  String get mermaidCatalogTemplateFlowchart =>
      'graph TD\n  A[Inicio]\n  B[Procesar paso]\n  C<MERMAID_OPEN_BRACE>Condición<MERMAID_CLOSE_BRACE>\n  D[Fin]\n\n  A --> B\n  B --> C\n  C -->|Sí| D\n  C -->|No| B';

  @override
  String get mermaidCatalogTemplateSequenceDiagram =>
      'sequenceDiagram\n  participant \"Usuario\" as user\n  participant \"Sistema\" as system\n  participant \"Base de datos\" as database\n\n  user->>system: Enviar solicitud\n  system->>database: Consultar datos\n  database-->>system: Devolver resultado\n  system-->>user: Mostrar resultado';

  @override
  String get mermaidCatalogTemplateClassDiagram =>
      'classDiagram\n  class Person <MERMAID_OPEN_BRACE>\n    +String nombre\n    +int edad\n    +getName() String\n    +setName(String nombre) void\n  <MERMAID_CLOSE_BRACE>\n  class Student <MERMAID_OPEN_BRACE>\n    +String studentId\n    +study() void\n  <MERMAID_CLOSE_BRACE>\n  class Teacher <MERMAID_OPEN_BRACE>\n    +String teacherId\n    +teach() void\n  <MERMAID_CLOSE_BRACE>\n  Student --|> Person\n  Teacher --|> Person';

  @override
  String get mermaidCatalogTemplateStateDiagram =>
      'stateDiagram-v2\n  state \"Pendiente\" as pending\n  state \"En proceso\" as processing\n  state \"Completado\" as completed\n  state \"Error\" as failed\n  [*] --> pending\n  pending --> processing\n  processing --> completed\n  processing --> failed\n  failed --> pending\n  completed --> [*]';

  @override
  String get mermaidCatalogTemplateErDiagram =>
      'erDiagram\n  CLIENTE ||--o<MERMAID_OPEN_BRACE> PEDIDO : realiza\n  PEDIDO ||--|<MERMAID_OPEN_BRACE> ARTICULO_PEDIDO : contiene\n  PRODUCTO ||--o<MERMAID_OPEN_BRACE> ARTICULO_PEDIDO : incluye\n  CLIENTE <MERMAID_OPEN_BRACE>\n    int id PK\n    string nombre\n    string correo\n  <MERMAID_CLOSE_BRACE>\n  PEDIDO <MERMAID_OPEN_BRACE>\n    int id PK\n    int id_cliente FK\n    date fecha_pedido\n  <MERMAID_CLOSE_BRACE>\n  PRODUCTO <MERMAID_OPEN_BRACE>\n    int id PK\n    string nombre\n    float precio\n  <MERMAID_CLOSE_BRACE>';

  @override
  String get mermaidCatalogTemplateGantt =>
      'gantt\n  title Cronograma del proyecto\n  dateFormat  YYYY-MM-DD\n  axisFormat  %m/%d\n\n  section Requisitos\n  Análisis de requisitos :a1, 2024-01-01, 14d\n  Diseño del prototipo   :a2, after a1, 10d\n\n  section Desarrollo\n  Desarrollo frontend   :b1, after a2, 20d\n  Desarrollo backend    :b2, after a2, 20d\n  Integración de API    :b3, after b1, 7d\n\n  section Pruebas\n  Pruebas funcionales   :c1, after b3, 10d\n  Despliegue            :c2, after c1, 3d';

  @override
  String get mermaidCatalogTemplatePie =>
      'pie showData\n  title Distribución de datos\n  \"Categoría A\" : 40\n  \"Categoría B\" : 25\n  \"Categoría C\" : 20\n  \"Categoría D\" : 15';

  @override
  String get mermaidCatalogTemplateJourney =>
      'journey\n  title Registro de usuario\n  section Registro\n    Abrir página de registro: 5: Usuario\n    Introducir datos: 3: Usuario\n    Enviar solicitud: 4: Usuario\n  section Verificación\n    Recibir código: 3: Sistema\n    Introducir código: 4: Usuario\n    Verificación correcta: 5: Sistema, Usuario';

  @override
  String get mermaidCatalogTemplateGitGraph =>
      'gitGraph\n  commit id: \"Commit inicial\"\n  commit id: \"Añadir función A\"\n  branch develop\n  checkout develop\n  commit id: \"Desarrollar función\"\n  commit id: \"Corregir error\"\n  checkout main\n  merge develop\n  commit id: \"Publicar v1.0\"';

  @override
  String get mermaidCatalogTemplateMindmap =>
      'mindmap\n  root((Gestión de proyectos))\n    Requisitos\n      Funcionales\n      No funcionales\n    Desarrollo\n      Frontend\n      Backend\n    Pruebas\n      Pruebas unitarias\n      Pruebas de integración\n    Despliegue\n      Entorno de pruebas\n      Entorno de producción';

  @override
  String get mermaidCatalogTemplateTimeline =>
      'timeline\n  title Hitos del proyecto\n  2024-Q1 : Análisis de requisitos : Plan confirmado\n  2024-Q2 : Desarrollo : Funciones implementadas\n  2024-Q3 : Pruebas : Corrección de errores : Optimización del rendimiento\n  2024-Q4 : Despliegue : Operación y mantenimiento';

  @override
  String get mermaidCatalogTemplateBlock =>
      'block-beta\n  columns 3\n  A[\"Requisitos\"] B[\"Desarrollo\"] C[\"Pruebas\"]\n  D[\"Despliegue\"] E[\"Operaciones\"] F[\"Supervisión\"]\n  A --> B\n  B --> C\n  C --> D\n  D --> E\n  E --> F';

  @override
  String get mermaidCatalogTemplateRequirement =>
      'requirementDiagram\n  requirement InicioSesion <MERMAID_OPEN_BRACE>\n    id: 1\n    text: El usuario puede iniciar sesión con su cuenta y contraseña\n    risk: medium\n    verifyMethod: test\n  <MERMAID_CLOSE_BRACE>\n  element PaginaInicio <MERMAID_OPEN_BRACE>\n    type: UI\n  <MERMAID_CLOSE_BRACE>\n  element ServicioAutenticacion <MERMAID_OPEN_BRACE>\n    type: Service\n  <MERMAID_CLOSE_BRACE>\n  PaginaInicio - satisfies -> InicioSesion\n  ServicioAutenticacion - verifies -> InicioSesion';

  @override
  String get mermaidCatalogDefaultFileName => 'mi tabla';

  @override
  String get mermaidCatalogActionAddNode => 'Agregar nodo';

  @override
  String get mermaidCatalogActionAddDecision => 'Agregar decisión';

  @override
  String get mermaidCatalogActionAddEdge => 'Agregar borde';

  @override
  String get mermaidCatalogActionAddSubgraph => 'Agregar subgrafo';

  @override
  String get mermaidCatalogActionAddParticipant => 'Agregar participante';

  @override
  String get mermaidCatalogActionAddRequest => 'Agregar solicitud';

  @override
  String get mermaidCatalogActionAddResponse => 'Agregar respuesta';

  @override
  String get mermaidCatalogActionAddNote => 'Agregar nota';

  @override
  String get mermaidCatalogActionAddClass => 'Agregar clase';

  @override
  String get mermaidCatalogActionAddInheritance => 'Agregar herencia';

  @override
  String get mermaidCatalogActionAddRelationship => 'Agregar relación';

  @override
  String get mermaidCatalogActionAddAggregation => 'Agregar agregación';

  @override
  String get mermaidCatalogActionAddState => 'Agregar estado';

  @override
  String get mermaidCatalogActionAddTransition => 'Agregar transición';

  @override
  String get mermaidCatalogActionAddStart => 'Agregar inicio';

  @override
  String get mermaidCatalogActionAddEnd => 'Añadir final';

  @override
  String get mermaidCatalogActionAddEntity => 'Agregar entidad';

  @override
  String get mermaidCatalogActionAddOneToMany => 'Agregar uno a muchos';

  @override
  String get mermaidCatalogActionAddManyToMany => 'Agregar muchos a muchos';

  @override
  String get mermaidCatalogActionAddOneToOne => 'Agregar uno a uno';

  @override
  String get mermaidCatalogActionAddPhase => 'Agregar fase';

  @override
  String get mermaidCatalogActionAddTask => 'Agregar tarea';

  @override
  String get mermaidCatalogActionAddDependentTask =>
      'Agregar tarea dependiente';

  @override
  String get mermaidCatalogActionAddMilestone => 'Agregar hito';

  @override
  String get mermaidCatalogActionAddCategory => 'Añadir categoría';

  @override
  String get mermaidCatalogActionAddTitle => 'Agregar título';

  @override
  String get mermaidCatalogActionAddSystemTask => 'Agregar tarea del sistema';

  @override
  String get mermaidCatalogActionAddMultiPersonTask =>
      'Agregar tarea para varias personas';

  @override
  String get mermaidCatalogActionAddCommit => 'Agregar compromiso';

  @override
  String get mermaidCatalogActionCreateBranch => 'Crear sucursal';

  @override
  String get mermaidCatalogActionSwitchBranch => 'Cambiar rama';

  @override
  String get mermaidCatalogActionMergeBranch => 'Fusionar rama';

  @override
  String get mermaidCatalogActionAddBranch => 'Agregar sucursal';

  @override
  String get mermaidCatalogActionAddChildBranch => 'Agregar rama secundaria';

  @override
  String get mermaidCatalogActionAddTopic => 'Agregar tema';

  @override
  String get mermaidCatalogActionAddPeriod => 'Agregar periodo';

  @override
  String get mermaidCatalogActionAddBlock => 'Agregar bloque';

  @override
  String get mermaidCatalogActionAddColumns => 'Agregar columnas';

  @override
  String get mermaidCatalogActionAddConnection => 'Agregar conexión';

  @override
  String get mermaidCatalogActionAddChildBlock => 'Agregar bloque infantil';

  @override
  String get mermaidCatalogActionAddRequirement => 'Agregar requisito';

  @override
  String get mermaidCatalogActionAddElement => 'Agregar elemento';

  @override
  String get mermaidCatalogActionAddVerification => 'Agregar verificación';

  @override
  String get mermaidCatalogGanttDependencyBaseTask =>
      'Tarea base de dependencia';

  @override
  String get mermaidCatalogGanttDependentTaskName => 'tarea de seguimiento';

  @override
  String get startupMigrationTitle =>
      'Actualización del formato de datos completada';

  @override
  String get startupMigrationBody =>
      'Sus datos han sido migrados al nuevo formato. Reinicie la aplicación para usar la versión actualizada.';

  @override
  String get startupMigrationExit => 'Salir de la aplicación';

  @override
  String get startupMigrationRestart => 'Reiniciar ahora';

  @override
  String get startupRecoveryTitle => 'Error de inicio de la aplicación';

  @override
  String get startupRecoveryFallbackMessage =>
      'Se encontró un problema de formato de datos durante el inicio y se reparó automáticamente. Por favor inténtalo de nuevo.';

  @override
  String get startupRecoveryRetry => 'Rever';

  @override
  String asrFailureDiagnosticFormat(
    Object category,
    Object stage,
    Object chunk,
    Object message,
  ) {
    return 'ASR $category en $stage$chunk: $message';
  }

  @override
  String asrFailureChunkPosition(Object index, Object count) {
    return ', fragmento $index/$count';
  }

  @override
  String asrFailureRequestFailed(Object detail) {
    return 'Solicitud fallida: $detail';
  }

  @override
  String asrChunkAllFailed(Object count) {
    return 'Error en la transcripción fragmentada (fragmentos $count, ninguno exitoso)';
  }

  @override
  String asrChunkIncomplete(Object succeeded, Object count) {
    return 'La transcripción fragmentada está incompleta (los fragmentos $succeeded/$count se realizaron correctamente)';
  }

  @override
  String asrChunkSucceeded(Object detail) {
    return 'Tuvo éxito: $detail';
  }

  @override
  String asrChunkFailed(Object detail) {
    return 'Error: $detail';
  }

  @override
  String asrChunkUncertain(Object detail) {
    return 'Resultado incierto: $detail';
  }

  @override
  String asrChunkDetails(
    Object index,
    Object start,
    Object end,
    Object status,
  ) {
    return 'Fragmento $index ($start–${end}s) $status';
  }

  @override
  String asrChunkCheckpointFailure(Object detail) {
    return 'Error al guardar el estado del fragmento: $detail';
  }

  @override
  String get asrChunkUncertainGuidance =>
      'El resultado de la solicitud es incierto. Se detuvieron los reintentos para evitar envíos duplicados. Seleccione el audio nuevamente para crear una nueva tarea.';

  @override
  String asrRetryAudioLost(Object audioName) {
    return 'El archivo de audio original se perdió. Seleccione el audio nuevamente para volver a intentarlo: $audioName';
  }

  @override
  String asrRetryAudioCorrupt(Object audioName) {
    return 'El archivo de audio original está dañado. Seleccione el audio nuevamente para volver a intentarlo: $audioName';
  }

  @override
  String asrFailureChunkIndex(Object index) {
    return ', trozo $index';
  }

  @override
  String get asrChunkDetailsSeparator => ';';

  @override
  String asrRecognitionFailed(Object detail) {
    return 'Error en el reconocimiento de ASR: $detail';
  }

  @override
  String get asrFailureCategoryAuthentication => 'autenticación';

  @override
  String get asrFailureCategoryRateLimit => 'límite de tasa';

  @override
  String get asrFailureCategorySizeLimit => 'límite de tamaño';

  @override
  String get asrFailureCategoryNetwork => 'red';

  @override
  String get asrFailureCategoryResponseParsing => 'análisis de respuesta';

  @override
  String get asrFailureCategoryLocalProcessing => 'procesamiento local';

  @override
  String get asrFailureCategoryProvider => 'proveedor';

  @override
  String get asrFailureCategoryUnknown => 'desconocido';

  @override
  String get asrFailureStagePreprocessing => 'preprocesamiento';

  @override
  String get asrFailureStageEncoding => 'codificación';

  @override
  String get asrFailureStageValidation => 'validación';

  @override
  String get asrFailureStageRequest => 'pedido';

  @override
  String get asrFailureStageUploading => 'subiendo';

  @override
  String get asrFailureStageWaiting => 'espera';

  @override
  String get asrFailureStageReceiving => 'recepción';

  @override
  String get asrFailureStageResponse => 'respuesta';

  @override
  String get asrFailureStageParsing => 'analizando';

  @override
  String get asrFailureStageStorage => 'almacenamiento';

  @override
  String get chatMissingProvider => 'Primero configure un proveedor de chat';

  @override
  String anthropicStreamApiError(Object detail) {
    return 'Error de API antrópico: $detail';
  }

  @override
  String get anthropicStreamUnknownError => 'Error desconocido';

  @override
  String chatHttpRequestFailed(Object statusCode, Object detail) {
    return 'La solicitud de API falló (HTTP $statusCode): $detail';
  }

  @override
  String get fileUploadApiKeyMissing =>
      'La clave API no está configurada; la carga de archivos no está disponible';

  @override
  String get fileUploadApiUrlMissing =>
      'La URL de API no está configurada; la carga de archivos no está disponible';

  @override
  String get fileUploadContentEmpty => 'El contenido del archivo está vacío.';

  @override
  String get fileUploadFilenameEmpty => 'El nombre del archivo está vacío.';

  @override
  String get fileUploadMimeTypeEmpty => 'El tipo MIME está vacío.';

  @override
  String get fileUploadPurposeEmpty => 'El propósito de carga está vacío';

  @override
  String get fileUploadCanceled => 'La carga del archivo fue cancelada.';

  @override
  String get fileUploadCreateMissingId =>
      'Error al crear la carga: falta la identificación de carga en la respuesta';

  @override
  String get fileUploadPartMissingId =>
      'Error al cargar la pieza: falta la identificación de la pieza en la respuesta';

  @override
  String get fileUploadCompleteMissingFile =>
      'Error al completar la carga: falta el objeto de archivo en la respuesta';

  @override
  String get fileUploadMissingFileId =>
      'Error al cargar el archivo: falta la identificación del archivo en la respuesta';

  @override
  String fileUploadRequestFailedStatus(Object statusCode, Object detail) {
    return 'Error en la solicitud de carga de archivos (HTTP $statusCode): $detail';
  }

  @override
  String fileUploadRequestFailed(Object detail) {
    return 'Error en la solicitud de carga de archivos: $detail';
  }

  @override
  String get chatApiKeyNotConfigured => 'La clave API no está configurada';

  @override
  String chatStreamError(Object detail) {
    return 'Error de flujo de API: $detail';
  }

  @override
  String get chatChoicesMissing => 'La respuesta API no tiene opciones';

  @override
  String get chatContentBlocksMissing =>
      'La respuesta API no tiene bloques de contenido';

  @override
  String get chatResponseContentEmpty =>
      'El contenido de la respuesta API está vacío';

  @override
  String chatRequestFailed(Object detail) {
    return 'Solicitud fallida: $detail';
  }

  @override
  String get startupTagline => 'Tu asistente de aprendizaje';

  @override
  String get startupProgressDataSafety =>
      'Comprobando la seguridad de los datos...';

  @override
  String get startupProgressFormatVersion =>
      'Comprobando la versión del formato de datos...';

  @override
  String get startupProgressDataFormat => 'Validando formatos de datos...';

  @override
  String get startupProgressDataIntegrity =>
      'Comprobando la integridad de los datos...';

  @override
  String get startupProgressResults =>
      'Procesando resultados de verificación...';

  @override
  String startupProgressCompleteWithWarnings(Object warning) {
    return 'Inicio completo (nota: $warning)';
  }

  @override
  String get startupProgressCompleteAfterMigration =>
      'Verificaciones de datos completadas. Preparándose para iniciar la aplicación.';

  @override
  String get startupProgressReady => 'Preparándose para iniciar la aplicación.';

  @override
  String startupWarningErrorCount(Object count) {
    return 'Problemas de datos encontrados con $count:';
  }

  @override
  String startupWarningWarningCount(Object count) {
    return 'Advertencias $count:';
  }

  @override
  String get startupIssueProviderEntriesInvalid =>
      'Las entradas del proveedor tienen un formato no válido: se esperaba una matriz JSON.';

  @override
  String startupIssueProviderEntryInvalid(Object index) {
    return 'La entrada del proveedor $index es nula o tiene un tipo no válido.';
  }

  @override
  String startupIssueProviderIdMissing(Object index) {
    return 'A la entrada del proveedor $index le falta un ID o tiene un ID vacío.';
  }

  @override
  String startupIssueProviderTypeMissing(Object index) {
    return 'A la entrada del proveedor $index le falta un tipo o tiene un tipo vacío.';
  }

  @override
  String startupIssueProviderNameMissing(Object index) {
    return 'A la entrada del proveedor $index le falta un nombre o tiene un nombre vacío.';
  }

  @override
  String startupIssueProviderListInvalid(Object index, Object field) {
    return 'El campo $field de la entrada de proveedor $index no es una lista válida.';
  }

  @override
  String startupIssueProviderNestedItemInvalid(Object index, Object field) {
    return 'La entrada del proveedor $index, $field contiene un elemento no válido que puede provocar un error de análisis.';
  }

  @override
  String get startupIssueConversationsInvalid =>
      'Las conversaciones tienen un formato no válido: se esperaba una matriz JSON.';

  @override
  String startupIssueConversationInvalid(Object index) {
    return 'La conversación $index es nula o tiene un tipo no válido.';
  }

  @override
  String startupIssueConversationIdMissing(Object index) {
    return 'A la conversación $index le falta un ID.';
  }

  @override
  String startupIssueConversationMessagesMissing(Object index) {
    return 'A la conversación $index le falta el campo de mensajes.';
  }

  @override
  String startupIssueConversationMessagesInvalid(Object index) {
    return 'El campo de mensajes de conversación $index no es una lista válida.';
  }

  @override
  String startupIssueUnknownProviderType(Object index, Object type) {
    return 'La entrada de proveedor $index utiliza el tipo de proveedor desconocido \"$type\" y es posible que no funcione correctamente.';
  }

  @override
  String get startupErrorTitle => 'Error al iniciar la aplicación';

  @override
  String startupErrorDetails(Object error) {
    return 'Error: $error';
  }

  @override
  String get renderErrorTitle => 'Error de representación de interfaz';

  @override
  String get renderErrorDebugTitle =>
      'Error de representación de interfaz (modo de depuración)';

  @override
  String get renderErrorRestartMessage => 'Intente reiniciar la aplicación.';

  @override
  String get batchDlgFileName => 'Nombre del archivo';

  @override
  String get batchDlgFolderName => 'Nombre de la carpeta';

  @override
  String get batchDlgFileNameConflict =>
      'Otro archivo en esta carpeta tiene el mismo nombre.';

  @override
  String get batchDlgFolderNameConflict =>
      'Ya existe una carpeta con el mismo nombre en la ubicación de destino';

  @override
  String get batchDlgFolderNameSwapConflict =>
      'Los nombres de las carpetas no se pueden intercambiar en el mismo lote';

  @override
  String get batchDlgControlCharacterError =>
      'El nombre no puede contener caracteres de control';

  @override
  String get batchDlgNameWhitespaceError =>
      'El nombre no puede comenzar ni terminar con espacios en blanco; utilizar la regla de limpieza de espacios en blanco';

  @override
  String batchDlgNameEmpty(String kind) {
    return '$kind no puede estar vacío';
  }

  @override
  String batchDlgNameTrailingWhitespace(String kind) {
    return '$kind no puede terminar con espacios en blanco';
  }

  @override
  String batchDlgNameTooLong(String kind, String count) {
    return '$kind no puede exceder los caracteres $count';
  }

  @override
  String batchDlgNameIllegalCharacters(String kind) {
    return '$kind no puede contener caracteres no válidos para Windows';
  }

  @override
  String batchDlgNameTrailingDot(String kind) {
    return '$kind no puede terminar con un punto';
  }

  @override
  String batchDlgNameReserved(String kind) {
    return '$kind no puede utilizar un nombre reservado de Windows';
  }

  @override
  String get batchDlgIntermediateNameTooLong =>
      'Un nombre intermedio es demasiado largo; ajustar las reglas';

  @override
  String batchDlgTemplateMissingDate(String date) {
    return 'Este artículo no tiene fecha $date; ajustar la plantilla';
  }

  @override
  String get batchDlgCreatedDate => 'creación';

  @override
  String get batchDlgModifiedDate => 'modificación';

  @override
  String get connectivityTestHttpSuccess =>
      'La solicitud de la herramienta HTTP se realizó correctamente';

  @override
  String get connectivityTestHttpFailure =>
      'Error en la solicitud de herramienta HTTP';

  @override
  String get connectivityTestInvalidMcpConfig =>
      'Configuración de MCP no válida';

  @override
  String get connectivityTestMissingTransport =>
      'Falta una configuración de tipo de transporte válida.';

  @override
  String get connectivityTestStdioUnsupported =>
      'stdio no es compatible con esta plataforma';

  @override
  String get connectivityTestStdioDesktopOnly =>
      'stdio MCP requiere iniciar un proceso local. Pruébelo en la aplicación de escritorio Stroom.';

  @override
  String get connectivityTestInvalidContent => 'Contenido de prueba no válido';

  @override
  String get connectivityTestMethodMustBeString =>
      'El método debe ser una cadena.';

  @override
  String get connectivityTestUnsupportedMethod =>
      'Método de prueba no compatible';

  @override
  String get connectivityTestReadOnlyMethodOnly =>
      'Para evitar escribir datos comerciales remotos, las pruebas de conectividad de MCP solo permiten el método de lista/herramientas de solo lectura.';

  @override
  String get connectivityTestParamsMustBeObject =>
      'los parámetros deben ser un objeto JSON.';

  @override
  String get connectivityTestMcpConnectionFailed =>
      'No se pudo conectar al servicio MCP';

  @override
  String get connectivityTestCheckConnectionSettings =>
      'Verifique la dirección, la autenticación y la red, o vea el registro de la aplicación para obtener detalles de la conexión.';

  @override
  String get connectivityTestRemainingToolsOmitted =>
      '; herramientas restantes omitidas';

  @override
  String get connectivityTestMcpSuccess =>
      'La prueba de conectividad MCP fue exitosa';

  @override
  String connectivityTestToolNames(Object names) {
    return ': $names';
  }

  @override
  String connectivityTestMcpSuccessDetails(
    int count,
    String names,
    String suffix,
  ) {
    return 'La conexión y la solicitud de lista/herramientas fueron exitosas; herramientas $count encontradas$names$suffix.';
  }

  @override
  String get connectivityTestTodoMutationBlocked =>
      'Los parámetros de prueba modificarían los datos de tareas pendientes.';

  @override
  String get connectivityTestTodoReadOnly =>
      'Para proteger la lista de tareas pendientes de la sesión actual, omita todas o configúrela como nula en las pruebas de conectividad.';

  @override
  String get connectivityTestUnknownBuiltin =>
      'Herramienta incorporada desconocida';

  @override
  String connectivityTestBuiltinExecutorMissing(String toolName) {
    return 'No se encontró ningún ejecutor de prueba para la herramienta \"$toolName\".';
  }

  @override
  String get connectivityTestBuiltinSuccess =>
      'La prueba de la herramienta incorporada fue exitosa';

  @override
  String get connectivityTestBuiltinFailure =>
      'La prueba de la herramienta integrada falló';

  @override
  String get connectivityTestTopLevelObjectRequired =>
      'El contenido de la prueba debe ser un objeto JSON de nivel superior.';

  @override
  String get connectivityTestRequestTimeout =>
      'Se agotó el tiempo de espera de la solicitud. Consulta la respuesta del servicio y la red.';

  @override
  String connectivityTestMcpRequestTimeout(String method) {
    return 'Se agotó el tiempo de espera de la solicitud de MCP: $method';
  }

  @override
  String get connectivityTestResultTruncated => '… (resultado truncado)';

  @override
  String get toolResultWebSearchEmptyQuery =>
      'Error: la consulta de búsqueda no puede estar vacía.';

  @override
  String toolResultWebSearchInvalidSource(Object source) {
    return 'Error: Motor de búsqueda no compatible \"$source\". Valores admitidos: google, bing, baidu.';
  }

  @override
  String toolResultWebSearchFallback(
    Object preferred,
    Object reason,
    Object fallback,
  ) {
    return 'El motor preferido $preferred $reason; cambiado a $fallback.';
  }

  @override
  String get toolResultWebSearchNotFound =>
      'No se encontraron resultados de búsqueda relevantes.';

  @override
  String toolResultWebSearchNotFoundFrom(Object sources) {
    return 'No se encontraron resultados de búsqueda relevantes ($sources explícitamente no arrojó resultados).';
  }

  @override
  String toolResultWebSearchIncomplete(Object sources, Object failures) {
    return 'Búsqueda incompleta: $sources explícitamente no arrojó resultados; otros motores no estaban disponibles o devolvieron páginas que no se pudieron analizar: $failures';
  }

  @override
  String toolResultWebSearchUnavailable(Object failures) {
    return 'Error: Todos los motores de búsqueda no están disponibles. $failures';
  }

  @override
  String toolResultWebSearchResultsHeader(Object source) {
    return 'Resultados de la búsqueda de $source:';
  }

  @override
  String get toolResultWebSearchLinkLabel => 'Enlace';

  @override
  String get toolResultWebSearchSummaryLabel => 'Resumen';

  @override
  String get toolResultWebSearchEmptyResults =>
      'No se encontraron resultados de búsqueda relevantes.';

  @override
  String get toolResultTodoInvalid =>
      'Error: el parámetro todos debe ser una matriz (omítalo o pase nulo para leer la lista de tareas pendientes).';

  @override
  String get toolResultTodoEmpty => 'Aún no hay tareas pendientes.';

  @override
  String toolResultTodoCount(Object count) {
    return 'Elementos pendientes activos: $count';
  }

  @override
  String toolResultMcpReconnectFailed(Object server) {
    return 'Error: No se pudo volver a conectar al servidor MCP \"$server\".';
  }

  @override
  String toolResultMcpUnavailable(Object server) {
    return 'Error: el servidor MCP \"$server\" no está disponible actualmente.';
  }

  @override
  String toolResultMcpNoTools(Object server) {
    return 'Error: el servidor MCP \"$server\" no pudo conectarse o no devolvió herramientas. Verifique la configuración del servidor.';
  }

  @override
  String toolResultMcpAliasedName(Object tool, Object alias) {
    return 'La herramienta real \"$tool\" está publicada con el nombre de llamada \"$alias\" en este servidor.';
  }

  @override
  String toolResultMcpDuplicateNames(Object tool, Object routes) {
    return 'La herramienta \"$tool\" la proporcionan varios servidores MCP; utilice el nombre de llamada coincidente: $routes.';
  }

  @override
  String toolResultMcpAliasedConflict(Object tool) {
    return 'Error: la herramienta real \"$tool\" tiene un conflicto de nombres. Utilice uno de los nombres de llamada enumerados anteriormente.';
  }

  @override
  String toolResultMcpMissingTool(Object server, Object tool) {
    return 'Error: el servidor MCP \"$server\" no tiene ninguna herramienta llamada \"$tool\".';
  }

  @override
  String toolResultMcpAvailableTools(Object tools) {
    return 'Herramientas disponibles en este servidor: $tools. Utilice estos nombres en su lugar.';
  }

  @override
  String toolResultMcpAliasConflict(Object tool, Object routes) {
    return 'Error: la herramienta MCP \"$tool\" tiene actualmente un alias conflictivo. Utilice el nombre de llamada coincidente: $routes.';
  }

  @override
  String toolResultToolDisabled(Object tool) {
    return 'Error: la herramienta \"$tool\" está deshabilitada.';
  }

  @override
  String toolResultToolUnknown(Object tool) {
    return 'Error: herramienta desconocida \"$tool\"';
  }

  @override
  String get toolResultWebSearchFallbackNoResults => 'no devolvió resultados';

  @override
  String get toolResultWebSearchFallbackUnavailable =>
      'no está disponible temporalmente';

  @override
  String toolResultMcpServerRoute(Object server) {
    return '(servidor MCP $server)';
  }

  @override
  String get toolResultWebSearchUnparsedResults =>
      'devolvió una página que no se pudo analizar';

  @override
  String get toolResultSearchTitleLabel => 'Título';

  @override
  String get toolResultSearchContentLabel => 'Contenido';

  @override
  String toolResultHttpApiKeyMissing(Object provider) {
    return 'Error: La clave API $provider no está configurada. Configurarlo en ajustes.';
  }

  @override
  String toolResultHttpUrlMissing(Object provider) {
    return 'Error: la URL de la instancia $provider no está configurada. Configurarlo en ajustes.';
  }

  @override
  String toolResultHttpRequestFailedStatus(Object provider, Object statusCode) {
    return 'Error: Error en la solicitud $provider (HTTP $statusCode)';
  }

  @override
  String toolResultHttpRequestFailed(Object provider, Object detail) {
    return 'Error: Error en la solicitud $provider: $detail';
  }

  @override
  String toolResultHttpUnknownTool(Object provider) {
    return 'Error: herramienta HTTP desconocida \"$provider\"';
  }

  @override
  String toolResultMcpNotConnected(Object server) {
    return 'Error: el servidor MCP \"$server\" no está conectado.';
  }

  @override
  String toolResultMcpNoResponse(Object tool) {
    return 'Error: No hay respuesta de la herramienta MCP \"$tool\".';
  }

  @override
  String toolResultMcpCallFailed(Object detail) {
    return 'Error: $detail';
  }

  @override
  String get httpToolBraveDescription =>
      'Busque en la web con Brave Search API. Requiere una clave API.';

  @override
  String get httpToolBochaDescription =>
      'Busque en la web con la API de búsqueda Bocha AI. Requiere una clave API.';

  @override
  String get httpToolQueritDescription =>
      'Busque en la web con Querit Search. Requiere una clave API.';

  @override
  String get httpToolSearxngDescription =>
      'Un metabuscador autohospedado y centrado en la privacidad que agrega fuentes de búsqueda. Requiere una URL de instancia.';

  @override
  String get httpToolSearchQueryDescription => 'Términos de búsqueda.';

  @override
  String get httpToolSearchCountDescription =>
      'Número de resultados a devolver.';

  @override
  String get httpToolSearchCountMax20Description =>
      'Número de resultados a devolver (máximo 20).';

  @override
  String backupRestoreApkgImportSummary(int decks, int notes, int cards) {
    return 'Mazos $decks, notas $notes y tarjetas $cards importadas';
  }

  @override
  String backupRestoreApkgFileNotFound(String path) {
    return 'No se pudo encontrar el archivo .apkg seleccionado: $path';
  }

  @override
  String get backupRestoreApkgInvalidArchive =>
      'El archivo .apkg seleccionado está dañado o no es un archivo válido.';

  @override
  String get backupRestoreApkgCollectionMissing =>
      'El archivo .apkg no contiene collection.anki2.';

  @override
  String backupRestoreApkgTargetMissing(String path) {
    return 'Abra las tarjetas didácticas de Anki antes de importar o exportar un mazo: $path';
  }

  @override
  String get backupRestoreApkgDatabaseCorrupt =>
      'La base de datos de la colección de Anki está dañada.';

  @override
  String backupRestoreApkgLocalFileFailure(String path) {
    return 'No se pudo acceder al archivo Anki local: $path';
  }

  @override
  String backupRestoreApkgUnexpectedError(String path) {
    return 'La operación .apkg falló al acceder a esta ruta: $path';
  }

  @override
  String get backupRestoreApkgOperationFailed =>
      'La operación .apkg falló porque no se pudo leer el archivo o la base de datos.';

  @override
  String backupRestoreApkgExportFailed(String path) {
    return 'La plataforma Anki no se pudo empaquetar desde esta base de datos: $path';
  }

  @override
  String get ankiSyncStatusProtocolFailed =>
      'La respuesta del servidor de sincronización no es válida o está incompleta. Verifique que el servidor admita Anki sync v10.';

  @override
  String get ankiSyncStatusLoginRequired =>
      'Inicie sesión en Anki Sync antes de continuar.';

  @override
  String get ankiSyncStatusInvalidServerUrl =>
      'Ingrese una dirección de servidor de sincronización HTTP o HTTPS válida.';

  @override
  String get ankiSyncStatusHttpsRequired =>
      'Los servidores de sincronización remotos autohospedados deben utilizar HTTPS.';

  @override
  String get ankiSyncStatusConnectionTimeout =>
      'Se agotó el tiempo de espera de la solicitud de sincronización. Verifique la dirección del servidor y la red, luego vuelva a intentarlo.';

  @override
  String get ankiSyncStatusTlsFailure =>
      'No se pudo verificar el certificado del servidor. Verifique el certificado o configure una CA personalizada.';

  @override
  String get ankiSyncStatusConnectionFailure =>
      'No se pudo conectar al servidor de sincronización. Verifique la dirección y la red.';

  @override
  String get ankiSyncStatusRequestFailure =>
      'La solicitud de sincronización falló. Verifique el servidor y la red, luego vuelva a intentarlo.';

  @override
  String ankiSyncStatusServerHttpError(int statusCode) {
    return 'El servidor de sincronización devolvió HTTP $statusCode.';
  }

  @override
  String ankiSyncStatusResponseTooLarge(int limitMb) {
    return 'La respuesta de sincronización superó el límite de MB $limitMb.';
  }

  @override
  String get ankiSyncStatusLocalFileFailure =>
      'No se pudo leer ni limpiar un archivo de sincronización local. Verifique el acceso al disco y vuelva a intentarlo.';

  @override
  String get ankiSyncStatusCollectionInvalid =>
      'La colección no se pudo abrir, actualizar ni pasar la validación de esquema/SQLite. Restaure una colección válida o descárguela nuevamente.';

  @override
  String ankiSyncStatusServerAuthRejected(int statusCode) {
    return 'El servidor de sincronización rechazó la solicitud (HTTP $statusCode). Verifique las credenciales de inicio de sesión y los permisos del servidor.';
  }

  @override
  String ankiSyncStatusServerEndpointNotFound(int statusCode) {
    return 'No se pudo encontrar el punto final de sincronización (HTTP $statusCode). Verifique la dirección del servidor.';
  }

  @override
  String get ankiSyncStatusMediaProtocolFailed =>
      'El servidor de sincronización de medios devolvió una respuesta no válida. Comprueba que sea compatible con la sincronización de medios Anki y vuelve a intentarlo.';

  @override
  String get ankiSyncStatusMediaIndexCorrupt =>
      'El índice de sincronización de medios local está dañado. Restablezca los datos de sincronización de medios e inténtelo de nuevo.';

  @override
  String get ankiSyncStatusMediaIndexFailure =>
      'No se pudo leer ni actualizar el índice de sincronización de medios local.';

  @override
  String get ankiSyncStatusMediaChecksumMismatch =>
      'Un archivo multimedia descargado no superó la validación de la suma de comprobación. Vuelva a intentar la sincronización de medios.';

  @override
  String ankiSyncStatusMediaFilenameConflict(String filename) {
    return 'El archivo multimedia “$filename” tiene cambios locales y de servidor contradictorios. Haga una copia de seguridad y resuelva el conflicto de nombres antes de volver a intentarlo.';
  }

  @override
  String ankiSyncStatusMediaInvalidFilename(String filename) {
    return 'El nombre del archivo multimedia “$filename” no se puede sincronizar. Cambie el nombre a un nombre de archivo Anki válido y vuelva a intentarlo.';
  }

  @override
  String ankiSyncStatusMediaFileSizeLimit(int limitMb) {
    return 'Un archivo multimedia está vacío o supera el límite de MB $limitMb.';
  }

  @override
  String ankiSyncStatusMediaBatchLimitExceeded(int count, int limit) {
    return 'El archivo multimedia contiene entradas $count; el máximo es $limit incluido su manifiesto.';
  }

  @override
  String get ankiSyncStatusMediaSanityCheckFailed =>
      'Error en la verificación de sincronización de medios. Vuelva a intentar la sincronización.';

  @override
  String get ankiWebSyncUnsupportedPlatform =>
      'Inicie sesión en AnkiWeb para sincronizar en la web. Abra la configuración de Anki con el ícono de la nube para iniciar sesión.';

  @override
  String get ankiWebDecksUnsupportedPlatform =>
      'Para explorar o administrar mazos en la web, inicie sesión en AnkiWeb usando el ícono de la nube.';

  @override
  String get ankiStatsUnsupportedPlatform =>
      'Las estadísticas de Anki no están disponibles en esta plataforma.';

  @override
  String get ankiSyncStatusDeviceClockMismatch =>
      'El reloj del dispositivo difiere del del servidor de sincronización en más de 5 minutos. Corrige el reloj y vuelve a intentarlo.';

  @override
  String get ankiSyncStatusFullDownloadRequired =>
      'La verificación de estado de sincronización falló y los cambios locales se revirtieron. Descargue la colección de servidores completa y vuelva a intentarlo.';

  @override
  String get ankiSyncStatusFullTransferRequired =>
      'Esta colección no se puede sincronizar de forma incremental. Elija una carga o descarga completa para continuar.';

  @override
  String get ankiSyncStatusIncrementalSyncFailed =>
      'No se pudo completar la sincronización incremental. Verifique el servidor y la conexión, luego inténtelo nuevamente.';

  @override
  String get emojiCategorySmileys => 'Emoticonos';

  @override
  String get emojiCategoryPeople => 'Gente';

  @override
  String get emojiCategoryAnimals => 'animales';

  @override
  String get emojiCategoryFood => 'Alimento';

  @override
  String get emojiCategoryActivities => 'Actividades';

  @override
  String get emojiCategoryTravel => 'Viajar';

  @override
  String get emojiCategoryObjects => 'Objetos';

  @override
  String get emojiCategorySymbols => 'Símbolos';

  @override
  String get emojiCategoryFlags => 'Banderas';

  @override
  String get languageNameSpanish => 'Español';

  @override
  String get languageNameJapanese => 'japonés';

  @override
  String fileManagerDeleteEmptyFolderWithSubfoldersConfirm(
    Object count,
    Object name,
  ) {
    return '¿Eliminar la carpeta vacía “$name”? También se eliminarán sus $count subcarpetas.';
  }
}
