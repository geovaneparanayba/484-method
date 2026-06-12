import '../models/lesson.dart';

/// Lições da Fase 1 conforme docs/curriculo-fase1.md, na ordem de
/// desbloqueio. Threshold permissivo (60) em toda a fase: o objetivo
/// pedagógico aqui é confiança, não rigor.
const fase1Lessons = [licao01, licao02, licao03, licao04];
const licao01 = Lesson(
  id: 'fase1-licao01',
  title: 'Você já sabe inglês',
  objective: 'Você vai falar 5 palavras em inglês que já conhece — '
      'e descobrir que seu inglês já começou.',
  approvalThreshold: 60,
  items: [
    LessonItem(
      text: 'banana',
      translation: 'banana',
      example: 'I eat a banana every day.',
      exampleTranslation: 'Eu como uma banana todo dia.',
      audioAsset: 'audio/fase1/licao01/banana.mp3',
    ),
    LessonItem(
      text: 'cinema',
      translation: 'cinema',
      example: "Let's go to the cinema tonight.",
      exampleTranslation: 'Vamos ao cinema hoje à noite.',
      audioAsset: 'audio/fase1/licao01/cinema.mp3',
    ),
    LessonItem(
      text: 'hotel',
      translation: 'hotel',
      example: 'The hotel is near the airport.',
      exampleTranslation: 'O hotel fica perto do aeroporto.',
      audioAsset: 'audio/fase1/licao01/hotel.mp3',
    ),
    LessonItem(
      text: 'internet',
      translation: 'internet',
      example: 'The internet is slow today.',
      exampleTranslation: 'A internet está lenta hoje.',
      audioAsset: 'audio/fase1/licao01/internet.mp3',
    ),
    LessonItem(
      text: 'pizza',
      translation: 'pizza',
      example: 'I want a pizza, please.',
      exampleTranslation: 'Eu quero uma pizza, por favor.',
      audioAsset: 'audio/fase1/licao01/pizza.mp3',
    ),
  ],
);

/// Lição 2 — "Palavras do celular": inglês digital que o aluno usa todo dia.
const licao02 = Lesson(
  id: 'fase1-licao02',
  title: 'Palavras do celular',
  objective: 'Estas 5 palavras estão no seu celular agora mesmo — '
      'você só vai aprender o som certo delas.',
  approvalThreshold: 60,
  items: [
    LessonItem(
      text: 'app',
      translation: 'aplicativo',
      example: 'I use this app every day.',
      exampleTranslation: 'Eu uso este aplicativo todo dia.',
      audioAsset: 'audio/fase1/licao02/app.mp3',
    ),
    LessonItem(
      text: 'online',
      translation: 'online / conectado',
      example: 'Are you online now?',
      exampleTranslation: 'Você está online agora?',
      audioAsset: 'audio/fase1/licao02/online.mp3',
    ),
    LessonItem(
      text: 'email',
      translation: 'e-mail',
      example: 'Send me an email, please.',
      exampleTranslation: 'Me manda um e-mail, por favor.',
      audioAsset: 'audio/fase1/licao02/email.mp3',
    ),
    LessonItem(
      text: 'login',
      translation: 'login / acesso',
      example: 'My login is not working.',
      exampleTranslation: 'Meu login não está funcionando.',
      audioAsset: 'audio/fase1/licao02/login.mp3',
    ),
    LessonItem(
      text: 'video',
      translation: 'vídeo',
      example: 'Did you watch the video?',
      exampleTranslation: 'Você assistiu ao vídeo?',
      audioAsset: 'audio/fase1/licao02/video.mp3',
    ),
  ],
);

/// Lição 3 — "Comida": vocabulário simples e útil.
const licao03 = Lesson(
  id: 'fase1-licao03',
  title: 'Comida',
  objective: 'Comida é o inglês mais gostoso de treinar — '
      'e o que você mais vai usar em viagem.',
  approvalThreshold: 60,
  items: [
    LessonItem(
      text: 'coffee',
      translation: 'café',
      example: 'I need a coffee right now.',
      exampleTranslation: 'Eu preciso de um café agora.',
      audioAsset: 'audio/fase1/licao03/coffee.mp3',
    ),
    LessonItem(
      text: 'burger',
      translation: 'hambúrguer',
      example: 'This burger is really good.',
      exampleTranslation: 'Este hambúrguer está muito bom.',
      audioAsset: 'audio/fase1/licao03/burger.mp3',
    ),
    LessonItem(
      text: 'sandwich',
      translation: 'sanduíche',
      example: 'Can I have a sandwich?',
      exampleTranslation: 'Pode me ver um sanduíche?',
      audioAsset: 'audio/fase1/licao03/sandwich.mp3',
    ),
    LessonItem(
      text: 'cake',
      translation: 'bolo',
      example: 'The cake is delicious.',
      exampleTranslation: 'O bolo está delicioso.',
      audioAsset: 'audio/fase1/licao03/cake.mp3',
    ),
    LessonItem(
      text: 'water',
      translation: 'água',
      example: 'A glass of water, please.',
      exampleTranslation: 'Um copo de água, por favor.',
      audioAsset: 'audio/fase1/licao03/water.mp3',
    ),
  ],
);

/// Lição 4 — "Viagem": inglês de sobrevivência imediata.
const licao04 = Lesson(
  id: 'fase1-licao04',
  title: 'Viagem',
  objective: 'As 5 palavras que te levam do aeroporto ao hotel — '
      'inglês de sobrevivência.',
  approvalThreshold: 60,
  items: [
    LessonItem(
      text: 'airport',
      translation: 'aeroporto',
      example: 'The airport is far from here.',
      exampleTranslation: 'O aeroporto é longe daqui.',
      audioAsset: 'audio/fase1/licao04/airport.mp3',
    ),
    LessonItem(
      text: 'taxi',
      translation: 'táxi',
      example: 'Can you call a taxi for me?',
      exampleTranslation: 'Você pode chamar um táxi pra mim?',
      audioAsset: 'audio/fase1/licao04/taxi.mp3',
    ),
    LessonItem(
      text: 'bus',
      translation: 'ônibus',
      example: 'The bus leaves at nine.',
      exampleTranslation: 'O ônibus sai às nove.',
      audioAsset: 'audio/fase1/licao04/bus.mp3',
    ),
    LessonItem(
      text: 'passport',
      translation: 'passaporte',
      example: 'Here is my passport.',
      exampleTranslation: 'Aqui está o meu passaporte.',
      audioAsset: 'audio/fase1/licao04/passport.mp3',
    ),
    LessonItem(
      text: 'ticket',
      translation: 'passagem / ingresso',
      example: 'I lost my ticket.',
      exampleTranslation: 'Eu perdi minha passagem.',
      audioAsset: 'audio/fase1/licao04/ticket.mp3',
    ),
  ],
);
