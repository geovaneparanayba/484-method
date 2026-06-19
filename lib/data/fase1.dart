import '../models/lesson.dart';

/// Lições da Fase 1 conforme docs/curriculo-fase1.md, na ordem de
/// desbloqueio.
///
/// Calibração 2026-06 (ver Lesson.approvalThreshold): accuracy ≥ 75 +
/// fonema mínimo ≥ 65 separa pronúncia razoável de aportuguesada sem
/// exigir perfeição nativa. Ajustar com dados de beta, não por opinião.
///
/// Fonética: `ipa` é o IPA do inglês americano (casa com a voz dos áudios,
/// en-US); `phonetic` é a fonética simplificada em PT-BR com a sílaba forte
/// em MAIÚSCULA. As duas aparecem só no Livro Aberto (depois da 1ª tentativa).
/// São aproximações — revisar com ouvido nativo.
const fase1Lessons = [
  licao01, licao02, licao03, licao04, licao05,
  licao06, licao07, licao08, licao09, licao10,
];

const licao01 = Lesson(
  id: 'fase1-licao01',
  title: 'Quebrando o gelo',
  objective: 'Você vai falar 5 palavras em inglês que já conhece — '
      'e descobrir que seu inglês já começou.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'apple',
      translation: 'maçã',
      example: 'I eat an apple every day.',
      exampleTranslation: 'Eu como uma maçã todo dia.',
      audioAsset: 'audio/fase1/licao01/apple.mp3',
      ipa: '/ˈæpəl/',
      phonetic: 'É-pou',
    ),
    LessonItem(
      text: 'cinema',
      translation: 'cinema',
      example: "Let's go to the cinema tonight.",
      exampleTranslation: 'Vamos ao cinema hoje à noite.',
      audioAsset: 'audio/fase1/licao01/cinema.mp3',
      ipa: '/ˈsɪnəmə/',
      phonetic: 'SÍ-ne-ma',
    ),
    LessonItem(
      text: 'hotel',
      translation: 'hotel',
      example: 'The hotel is near the airport.',
      exampleTranslation: 'O hotel fica perto do aeroporto.',
      audioAsset: 'audio/fase1/licao01/hotel.mp3',
      ipa: '/hoʊˈtɛl/',
      phonetic: 'rrou-TÉL',
    ),
    LessonItem(
      text: 'internet',
      translation: 'internet',
      example: 'The internet is slow today.',
      exampleTranslation: 'A internet está lenta hoje.',
      audioAsset: 'audio/fase1/licao01/internet.mp3',
      ipa: '/ˈɪntərnɛt/',
      phonetic: 'ÍN-ter-nét',
    ),
    LessonItem(
      text: 'pizza',
      translation: 'pizza',
      example: 'I want a pizza, please.',
      exampleTranslation: 'Eu quero uma pizza, por favor.',
      audioAsset: 'audio/fase1/licao01/pizza.mp3',
      ipa: '/ˈpiːtsə/',
      phonetic: 'PÍT-sa',
    ),
  ],
);

/// Lição 2 — "Palavras do celular": inglês digital que o aluno usa todo dia.
const licao02 = Lesson(
  id: 'fase1-licao02',
  title: 'Palavras do celular',
  objective: 'Estas 5 palavras estão no seu celular agora mesmo — '
      'você só vai aprender o som certo delas.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'app',
      translation: 'aplicativo',
      example: 'I use this app every day.',
      exampleTranslation: 'Eu uso este aplicativo todo dia.',
      audioAsset: 'audio/fase1/licao02/app.mp3',
      ipa: '/æp/',
      phonetic: 'ÉP',
    ),
    LessonItem(
      text: 'online',
      translation: 'online / conectado',
      example: 'Are you online now?',
      exampleTranslation: 'Você está online agora?',
      audioAsset: 'audio/fase1/licao02/online.mp3',
      ipa: '/ˌɑːnˈlaɪn/',
      phonetic: 'on-LÁIN',
    ),
    LessonItem(
      text: 'email',
      translation: 'e-mail',
      example: 'Send me an email, please.',
      exampleTranslation: 'Me manda um e-mail, por favor.',
      audioAsset: 'audio/fase1/licao02/email.mp3',
      ipa: '/ˈiːmeɪl/',
      phonetic: 'Í-meil',
    ),
    LessonItem(
      text: 'login',
      translation: 'login / acesso',
      example: 'My login is not working.',
      exampleTranslation: 'Meu login não está funcionando.',
      audioAsset: 'audio/fase1/licao02/login.mp3',
      ipa: '/ˈlɔːɡɪn/',
      phonetic: 'LÓ-guin',
    ),
    LessonItem(
      text: 'video',
      translation: 'vídeo',
      example: 'Did you watch the video?',
      exampleTranslation: 'Você assistiu ao vídeo?',
      audioAsset: 'audio/fase1/licao02/video.mp3',
      ipa: '/ˈvɪdioʊ/',
      phonetic: 'VÍ-di-ou',
    ),
  ],
);

/// Lição 3 — "Comida": vocabulário simples e útil.
const licao03 = Lesson(
  id: 'fase1-licao03',
  title: 'Comida',
  objective: 'Comida é o inglês mais gostoso de treinar — '
      'e o que você mais vai usar em viagem.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'coffee',
      translation: 'café',
      example: 'I need a coffee right now.',
      exampleTranslation: 'Eu preciso de um café agora.',
      audioAsset: 'audio/fase1/licao03/coffee.mp3',
      ipa: '/ˈkɔːfi/',
      phonetic: 'CÓ-fi',
    ),
    LessonItem(
      text: 'burger',
      translation: 'hambúrguer',
      example: 'This burger is really good.',
      exampleTranslation: 'Este hambúrguer está muito bom.',
      audioAsset: 'audio/fase1/licao03/burger.mp3',
      ipa: '/ˈbɜːrɡər/',
      phonetic: 'BÉR-guer',
    ),
    LessonItem(
      text: 'sandwich',
      translation: 'sanduíche',
      example: 'Can I have a sandwich?',
      exampleTranslation: 'Pode me ver um sanduíche?',
      audioAsset: 'audio/fase1/licao03/sandwich.mp3',
      ipa: '/ˈsænwɪtʃ/',
      phonetic: 'SÉND-uitch',
    ),
    LessonItem(
      text: 'cake',
      translation: 'bolo',
      example: 'The cake is delicious.',
      exampleTranslation: 'O bolo está delicioso.',
      audioAsset: 'audio/fase1/licao03/cake.mp3',
      ipa: '/keɪk/',
      phonetic: 'KÊIK',
    ),
    LessonItem(
      text: 'water',
      translation: 'água',
      example: 'A glass of water, please.',
      exampleTranslation: 'Um copo de água, por favor.',
      audioAsset: 'audio/fase1/licao03/water.mp3',
      ipa: '/ˈwɔːtər/',
      phonetic: 'UÓ-ter',
    ),
  ],
);

/// Lição 4 — "Viagem": inglês de sobrevivência imediata.
const licao04 = Lesson(
  id: 'fase1-licao04',
  title: 'Viagem',
  objective: 'As 5 palavras que te levam do aeroporto ao hotel — '
      'inglês de sobrevivência.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'airport',
      translation: 'aeroporto',
      example: 'The airport is far from here.',
      exampleTranslation: 'O aeroporto é longe daqui.',
      audioAsset: 'audio/fase1/licao04/airport.mp3',
      ipa: '/ˈɛrpɔːrt/',
      phonetic: 'ÉR-port',
    ),
    LessonItem(
      text: 'taxi',
      translation: 'táxi',
      example: 'Can you call a taxi for me?',
      exampleTranslation: 'Você pode chamar um táxi pra mim?',
      audioAsset: 'audio/fase1/licao04/taxi.mp3',
      ipa: '/ˈtæksi/',
      phonetic: 'TÉK-si',
    ),
    LessonItem(
      text: 'bus',
      translation: 'ônibus',
      example: 'The bus leaves at nine.',
      exampleTranslation: 'O ônibus sai às nove.',
      audioAsset: 'audio/fase1/licao04/bus.mp3',
      ipa: '/bʌs/',
      phonetic: 'BÂS',
    ),
    LessonItem(
      text: 'passport',
      translation: 'passaporte',
      example: 'Here is my passport.',
      exampleTranslation: 'Aqui está o meu passaporte.',
      audioAsset: 'audio/fase1/licao04/passport.mp3',
      ipa: '/ˈpæspɔːrt/',
      phonetic: 'PÉS-port',
    ),
    LessonItem(
      text: 'ticket',
      translation: 'passagem / ingresso',
      example: 'I lost my ticket.',
      exampleTranslation: 'Eu perdi minha passagem.',
      audioAsset: 'audio/fase1/licao04/ticket.mp3',
      ipa: '/ˈtɪkɪt/',
      phonetic: 'TÍ-ket',
    ),
  ],
);

/// Lição 5 — "Trabalho": conexão com carreira.
const licao05 = Lesson(
  id: 'fase1-licao05',
  title: 'Trabalho',
  objective: 'Inglês de carreira: 5 palavras que aparecem em toda '
      'reunião, vaga e LinkedIn.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'meeting',
      translation: 'reunião',
      example: 'The meeting starts at ten.',
      exampleTranslation: 'A reunião começa às dez.',
      audioAsset: 'audio/fase1/licao05/meeting.mp3',
      ipa: '/ˈmiːtɪŋ/',
      phonetic: 'MÍ-tin',
    ),
    LessonItem(
      text: 'manager',
      translation: 'gerente / gestor',
      example: 'She is my manager.',
      exampleTranslation: 'Ela é minha gestora.',
      audioAsset: 'audio/fase1/licao05/manager.mp3',
      ipa: '/ˈmænɪdʒər/',
      phonetic: 'MÉ-ne-djer',
    ),
    LessonItem(
      text: 'project',
      translation: 'projeto',
      example: 'This project is important.',
      exampleTranslation: 'Este projeto é importante.',
      audioAsset: 'audio/fase1/licao05/project.mp3',
      ipa: '/ˈprɑːdʒɛkt/',
      phonetic: 'PRÓ-djekt',
    ),
    LessonItem(
      text: 'office',
      translation: 'escritório',
      example: 'I work at the office on Mondays.',
      exampleTranslation: 'Eu trabalho no escritório às segundas.',
      audioAsset: 'audio/fase1/licao05/office.mp3',
      ipa: '/ˈɔːfɪs/',
      phonetic: 'Ó-fis',
    ),
    LessonItem(
      text: 'job',
      translation: 'emprego / trabalho',
      example: 'I love my job.',
      exampleTranslation: 'Eu amo meu trabalho.',
      audioAsset: 'audio/fase1/licao05/job.mp3',
      ipa: '/dʒɑːb/',
      phonetic: 'DJÓB',
    ),
  ],
);

/// Lição 6 — "Ritmo diferente": palavras familiares com sílaba forte
/// traiçoeira para brasileiros (foco em stress, não em vocabulário).
const licao06 = Lesson(
  id: 'fase1-licao06',
  title: 'Palavras com ritmo diferente',
  objective: 'Você conhece estas palavras — mas o ritmo em inglês é '
      'diferente. Ouça onde está a força e copie.',
  approvalThreshold: 75,
  // Lição de ritmo: a prosódia entra no critério (pega sílaba forte errada).
  minProsody: 70,
  items: [
    LessonItem(
      text: 'hospital',
      translation: 'hospital',
      example: 'The hospital is open all night.',
      exampleTranslation: 'O hospital fica aberto a noite toda.',
      audioAsset: 'audio/fase1/licao06/hospital.mp3',
      ipa: '/ˈhɑːspɪtəl/',
      phonetic: 'RRÓS-pi-tou',
    ),
    LessonItem(
      text: 'chocolate',
      translation: 'chocolate',
      example: 'I want some chocolate.',
      exampleTranslation: 'Eu quero um chocolate.',
      audioAsset: 'audio/fase1/licao06/chocolate.mp3',
      ipa: '/ˈtʃɔːklət/',
      phonetic: 'TCHÓ-klet',
    ),
    LessonItem(
      text: 'camera',
      translation: 'câmera',
      example: 'Turn on your camera, please.',
      exampleTranslation: 'Liga sua câmera, por favor.',
      audioAsset: 'audio/fase1/licao06/camera.mp3',
      ipa: '/ˈkæmərə/',
      phonetic: 'KÉ-me-ra',
    ),
    LessonItem(
      text: 'restaurant',
      translation: 'restaurante',
      example: 'This restaurant is new.',
      exampleTranslation: 'Este restaurante é novo.',
      audioAsset: 'audio/fase1/licao06/restaurant.mp3',
      ipa: '/ˈrɛstərɑːnt/',
      phonetic: 'RÉS-te-ron',
    ),
    LessonItem(
      text: 'comfortable',
      translation: 'confortável',
      example: 'This chair is comfortable.',
      exampleTranslation: 'Esta cadeira é confortável.',
      audioAsset: 'audio/fase1/licao06/comfortable.mp3',
      ipa: '/ˈkʌmftərbəl/',
      phonetic: 'CÂMF-ter-bou',
    ),
  ],
);

/// Lição 7 — "Primeiros chunks": da palavra isolada à frase curta.
const licao07 = Lesson(
  id: 'fase1-licao07',
  title: 'Primeiros chunks',
  objective: 'Agora você sai da palavra solta: 5 frases curtas que '
      'saem prontas, sem montar palavra por palavra.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'I like it',
      translation: 'eu gosto (disso)',
      example: 'Nice idea. I like it!',
      exampleTranslation: 'Boa ideia. Eu gosto!',
      audioAsset: 'audio/fase1/licao07/I_like_it.mp3',
      ipa: '/aɪ ˈlaɪk ɪt/',
      phonetic: 'ai LÁIK it',
    ),
    LessonItem(
      text: 'I need it',
      translation: 'eu preciso (disso)',
      example: 'Where is my phone? I need it.',
      exampleTranslation: 'Cadê meu celular? Eu preciso dele.',
      audioAsset: 'audio/fase1/licao07/I_need_it.mp3',
      ipa: '/aɪ ˈniːd ɪt/',
      phonetic: 'ai NÍD it',
    ),
    LessonItem(
      text: 'I want this',
      translation: 'eu quero este(a)',
      example: 'Look at this one. I want this.',
      exampleTranslation: 'Olha este aqui. Eu quero este.',
      audioAsset: 'audio/fase1/licao07/I_want_this.mp3',
      ipa: '/aɪ ˈwɑːnt ðɪs/',
      phonetic: 'ai UÓNT dis',
    ),
    LessonItem(
      text: 'I love it',
      translation: 'eu adoro (isso)',
      example: 'This song? I love it!',
      exampleTranslation: 'Essa música? Eu adoro!',
      audioAsset: 'audio/fase1/licao07/I_love_it.mp3',
      ipa: '/aɪ ˈlʌv ɪt/',
      phonetic: 'ai LÂV it',
    ),
    LessonItem(
      text: 'I got it',
      translation: 'entendi / deixa comigo',
      example: 'No problem, I got it.',
      exampleTranslation: 'Sem problema, deixa comigo.',
      audioAsset: 'audio/fase1/licao07/I_got_it.mp3',
      ipa: '/aɪ ˈɡɑːt ɪt/',
      phonetic: 'ai GÓT it',
    ),
  ],
);

/// Lição 8 — "Frases de cortesia": comunicação imediata.
const licao08 = Lesson(
  id: 'fase1-licao08',
  title: 'Frases de cortesia',
  objective: 'As frases que destravam qualquer conversa: educação '
      'funciona em qualquer país.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'Thank you',
      translation: 'obrigado(a)',
      example: 'Thank you so much!',
      exampleTranslation: 'Muito obrigado!',
      audioAsset: 'audio/fase1/licao08/Thank_you.mp3',
      ipa: '/ˈθæŋk juː/',
      phonetic: 'TÉNK iu',
    ),
    LessonItem(
      text: 'See you',
      translation: 'até mais',
      example: 'Bye! See you tomorrow.',
      exampleTranslation: 'Tchau! Até amanhã.',
      audioAsset: 'audio/fase1/licao08/See_you.mp3',
      ipa: '/ˈsiː juː/',
      phonetic: 'SÍ iu',
    ),
    LessonItem(
      text: 'Excuse me',
      translation: 'com licença',
      example: 'Excuse me, is this seat free?',
      exampleTranslation: 'Com licença, este lugar está livre?',
      audioAsset: 'audio/fase1/licao08/Excuse_me.mp3',
      ipa: '/ɪkˈskjuːz miː/',
      phonetic: 'iks-KIÚZ mi',
    ),
    LessonItem(
      text: "It's okay",
      translation: 'tudo bem / está tudo certo',
      example: "Don't worry, it's okay.",
      exampleTranslation: 'Não se preocupe, está tudo bem.',
      audioAsset: "audio/fase1/licao08/It's_okay.mp3",
      ipa: '/ɪts oʊˈkeɪ/',
      phonetic: 'its ou-KÊI',
    ),
    LessonItem(
      text: 'No problem',
      translation: 'sem problema',
      example: 'Thanks for waiting. — No problem!',
      exampleTranslation: 'Valeu por esperar. — Sem problema!',
      audioAsset: 'audio/fase1/licao08/No_problem.mp3',
      ipa: '/noʊ ˈprɑːbləm/',
      phonetic: 'nôu PRÓ-blem',
    ),
  ],
);

/// Lição 9 — "Pequenos pedidos": fala funcional.
const licao09 = Lesson(
  id: 'fase1-licao09',
  title: 'Pequenos pedidos',
  objective: 'Pedir é a fala mais útil que existe: café, ajuda e '
      'tempo — tudo em frases prontas.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'Can I have a coffee',
      translation: 'pode me ver um café?',
      example: 'Hi! Can I have a coffee?',
      exampleTranslation: 'Oi! Pode me ver um café?',
      audioAsset: 'audio/fase1/licao09/Can_I_have_a_coffee.mp3',
      ipa: '/kæn aɪ hæv ə ˈkɔːfi/',
      phonetic: 'ken ai rrév e CÓ-fi',
    ),
    LessonItem(
      text: 'I need help',
      translation: 'eu preciso de ajuda',
      example: 'Sorry, I need help here.',
      exampleTranslation: 'Desculpe, preciso de ajuda aqui.',
      audioAsset: 'audio/fase1/licao09/I_need_help.mp3',
      ipa: '/aɪ niːd hɛlp/',
      phonetic: 'ai NÍD rrélp',
    ),
    LessonItem(
      text: 'One coffee, please',
      translation: 'um café, por favor',
      example: 'One coffee, please. To go.',
      exampleTranslation: 'Um café, por favor. Pra viagem.',
      audioAsset: 'audio/fase1/licao09/One_coffee,_please.mp3',
      ipa: '/wʌn ˈkɔːfi pliːz/',
      phonetic: 'uân CÓ-fi PLÍZ',
    ),
    LessonItem(
      text: 'Can you help me',
      translation: 'você pode me ajudar?',
      example: "Excuse me, can you help me?",
      exampleTranslation: 'Com licença, você pode me ajudar?',
      audioAsset: 'audio/fase1/licao09/Can_you_help_me.mp3',
      ipa: '/kæn ju hɛlp miː/',
      phonetic: 'ken iu rrélp mi',
    ),
    LessonItem(
      text: 'Just a minute',
      translation: 'só um minuto',
      example: 'Just a minute, I am almost ready.',
      exampleTranslation: 'Só um minuto, estou quase pronto.',
      audioAsset: 'audio/fase1/licao09/Just_a_minute.mp3',
      ipa: '/dʒʌst ə ˈmɪnɪt/',
      phonetic: 'djâst e MÍ-net',
    ),
  ],
);

/// Lição 10 — "Revisão guiada": mistura das lições anteriores,
/// reusando os áudios já gerados (consolidação de hábito).
const licao10 = Lesson(
  id: 'fase1-licao10',
  title: 'Revisão guiada',
  objective: 'Tudo que você já treinou, misturado: prove pra você '
      'mesmo o quanto avançou.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'hospital',
      translation: 'hospital',
      example: 'The hospital is open all night.',
      exampleTranslation: 'O hospital fica aberto a noite toda.',
      audioAsset: 'audio/fase1/licao06/hospital.mp3',
      ipa: '/ˈhɑːspɪtəl/',
      phonetic: 'RRÓS-pi-tou',
    ),
    LessonItem(
      text: 'coffee',
      translation: 'café',
      example: 'I need a coffee right now.',
      exampleTranslation: 'Eu preciso de um café agora.',
      audioAsset: 'audio/fase1/licao03/coffee.mp3',
      ipa: '/ˈkɔːfi/',
      phonetic: 'CÓ-fi',
    ),
    LessonItem(
      text: 'airport',
      translation: 'aeroporto',
      example: 'The airport is far from here.',
      exampleTranslation: 'O aeroporto é longe daqui.',
      audioAsset: 'audio/fase1/licao04/airport.mp3',
      ipa: '/ˈɛrpɔːrt/',
      phonetic: 'ÉR-port',
    ),
    LessonItem(
      text: 'I need it',
      translation: 'eu preciso (disso)',
      example: 'Where is my phone? I need it.',
      exampleTranslation: 'Cadê meu celular? Eu preciso dele.',
      audioAsset: 'audio/fase1/licao07/I_need_it.mp3',
      ipa: '/aɪ ˈniːd ɪt/',
      phonetic: 'ai NÍD it',
    ),
    LessonItem(
      text: 'Thank you',
      translation: 'obrigado(a)',
      example: 'Thank you so much!',
      exampleTranslation: 'Muito obrigado!',
      audioAsset: 'audio/fase1/licao08/Thank_you.mp3',
      ipa: '/ˈθæŋk juː/',
      phonetic: 'TÉNK iu',
    ),
  ],
);
