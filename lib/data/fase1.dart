import '../models/lesson.dart';

/// Lições da Fase 1 ("Inglês que Você Já Conhece"), organizadas em 4 blocos
/// pedagógicos — ver docs/curriculo-fase1.md.
///
/// Bloco 1 — Reconhecimento e confiança: vocabulário familiar.
/// Bloco 2 — Som e sílaba forte: ritmo e armadilhas de pronúncia.
/// Bloco 3 — Da palavra à frase: chunks, cortesia e situações reais.
/// Bloco 4 — Conversa do dia a dia: small talk, saudações e planos.
///
/// Os ids (`fase1-licaoNN`) têm lacunas: licao05 ("Muito fácil 2") e
/// licao08 ("Trabalho") foram removidas do currículo, mas os nomes não
/// foram renumerados para não invalidar progresso já salvo por id.
///
/// Cada bloco termina com uma revisão (obrigatória) e um bônus (opcional,
/// `Lesson.bonus = true`): mesmo assunto do bloco, mas com palavras/frases
/// mais difíceis. O bônus NUNCA é pré-requisito da próxima lição — a
/// progressão pula lições bônus ao decidir o que precisa estar concluído
/// (ver home_screen.dart).
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
  licao01, licao02, licao03, licao04, licao06, licao07,
  licao09, licao10, licao11, licao12, licao13,
  licao14, licao15, licao16, licao17, licao18, licao19, licao20,
  licao21, licao22, licao23, licao24, licao25, licao26, licao27,
];

// ---------------------------------------------------------------------------
// BLOCO 1 — Reconhecimento e confiança
// ---------------------------------------------------------------------------

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

/// Lição 6 — "Revisão Bloco 1": uma palavra de cada lição do bloco,
/// reaproveitando 100% dos áudios já gerados.
const licao06 = Lesson(
  id: 'fase1-licao06',
  title: 'Revisão de fala — Zona 1',
  objective: 'Uma palavra de cada lição que você já fez neste bloco. '
      'Veja como está sua pronúncia até aqui.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'pizza',
      translation: 'pizza',
      example: 'Two pizzas for the table, please.',
      exampleTranslation: 'Duas pizzas para a mesa, por favor.',
      audioAsset: 'audio/fase1/licao01/pizza.mp3',
      ipa: '/ˈpiːtsə/',
      phonetic: 'PÍT-sa',
    ),
    LessonItem(
      text: 'email',
      translation: 'e-mail',
      example: "I'll send you an email later.",
      exampleTranslation: 'Te mando um e-mail depois.',
      audioAsset: 'audio/fase1/licao02/email.mp3',
      ipa: '/ˈiːmeɪl/',
      phonetic: 'Í-meil',
    ),
    LessonItem(
      text: 'coffee',
      translation: 'café',
      example: 'Can I get a coffee to go?',
      exampleTranslation: 'Posso levar um café para viagem?',
      audioAsset: 'audio/fase1/licao03/coffee.mp3',
      ipa: '/ˈkɔːfi/',
      phonetic: 'CÓ-fi',
    ),
    LessonItem(
      text: 'ticket',
      translation: 'bilhete / ingresso',
      example: 'Where do I buy the ticket?',
      exampleTranslation: 'Onde compro o bilhete?',
      audioAsset: 'audio/fase1/licao04/ticket.mp3',
      ipa: '/ˈtɪkɪt/',
      phonetic: 'TÍ-ket',
    ),
    LessonItem(
      text: 'banana',
      translation: 'banana',
      example: 'Do you want a banana?',
      exampleTranslation: 'Você quer uma banana?',
      audioAsset: 'audio/fase1/muito_facil_2/banana.mp3',
      ipa: '/bəˈnænə/',
      phonetic: 'ba-NÉ-na',
    ),
  ],
);

/// Lição 7 — BÔNUS Bloco 1 — "Desafio: vocabulário avançado". Opcional:
/// não bloqueia a Lição 8 (a progressão olha para a Lição 6, não para esta).
const licao07 = Lesson(
  id: 'fase1-licao07',
  title: 'Desafio: vocabulário avançado',
  objective: 'Bônus opcional — mesmo assunto do bloco, palavras mais '
      'longas. Não precisa fazer para seguir em frente.',
  approvalThreshold: 75,
  bonus: true,
  items: [
    LessonItem(
      text: 'calendar',
      translation: 'calendário',
      example: 'Check the calendar for the date.',
      exampleTranslation: 'Confira o calendário para a data.',
      audioAsset: 'audio/fase1/bonus_vocabulario/calendar.mp3',
      ipa: '/ˈkælɪndər/',
      phonetic: 'KÉ-len-der',
    ),
    LessonItem(
      text: 'celebrity',
      translation: 'celebridade',
      example: 'She became a celebrity overnight.',
      exampleTranslation: 'Ela se tornou uma celebridade da noite para o dia.',
      audioAsset: 'audio/fase1/bonus_vocabulario/celebrity.mp3',
      ipa: '/səˈlɛbrəti/',
      phonetic: 'se-LÉ-bre-ti',
    ),
    LessonItem(
      text: 'vegetable',
      translation: 'vegetal / legume',
      example: 'Eat more vegetables.',
      exampleTranslation: 'Coma mais vegetais.',
      audioAsset: 'audio/fase1/bonus_vocabulario/vegetable.mp3',
      ipa: '/ˈvɛdʒtəbəl/',
      phonetic: 'VÉDJ-te-bou',
    ),
    LessonItem(
      text: 'elevator',
      translation: 'elevador',
      example: 'Take the elevator to the third floor.',
      exampleTranslation: 'Pegue o elevador até o terceiro andar.',
      audioAsset: 'audio/fase1/bonus_vocabulario/elevator.mp3',
      ipa: '/ˈɛləveɪtər/',
      phonetic: 'É-le-vei-ter',
    ),
    LessonItem(
      text: 'umbrella',
      translation: 'guarda-chuva',
      example: "Don't forget your umbrella.",
      exampleTranslation: 'Não esqueça seu guarda-chuva.',
      audioAsset: 'audio/fase1/bonus_vocabulario/umbrella.mp3',
      ipa: '/ʌmˈbrɛlə/',
      phonetic: 'am-BRÉ-la',
    ),
  ],
);

// ---------------------------------------------------------------------------
// BLOCO 2 — Som e sílaba forte
// ---------------------------------------------------------------------------

/// Lição 9 — "Ritmo diferente": palavras familiares com sílaba forte
/// traiçoeira para brasileiros (foco em stress, não em vocabulário).
const licao09 = Lesson(
  id: 'fase1-licao09',
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

/// Lição 10 — "Som enganoso": palavras parecidas com o português, onde o
/// sotaque mais aparece. Foco em treinar o ouvido para a diferença de som.
const licao10 = Lesson(
  id: 'fase1-licao10',
  title: 'Som enganoso',
  objective: 'Estas palavras parecem fáceis porque são parecidas com o '
      'português — e é exatamente aí que o sotaque aparece. Ouça com atenção.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'business',
      translation: 'negócio / empresa',
      example: 'She has her own business.',
      exampleTranslation: 'Ela tem o próprio negócio.',
      audioAsset: 'audio/fase1/som_enganoso/business.mp3',
      ipa: '/ˈbɪznəs/',
      phonetic: 'BÍZ-nes',
    ),
    LessonItem(
      text: 'interesting',
      translation: 'interessante',
      example: 'This book is very interesting.',
      exampleTranslation: 'Este livro é muito interessante.',
      audioAsset: 'audio/fase1/som_enganoso/interesting.mp3',
      ipa: '/ˈɪntrəstɪŋ/',
      phonetic: 'ÍN-tres-ting',
    ),
    LessonItem(
      text: 'mouse',
      translation: 'mouse (do computador)',
      example: 'My mouse is not working.',
      exampleTranslation: 'Meu mouse não está funcionando.',
      audioAsset: 'audio/fase1/som_enganoso/mouse.mp3',
      ipa: '/maʊs/',
      phonetic: 'MÁUS',
    ),
    LessonItem(
      text: 'delivery',
      translation: 'entrega',
      example: 'The delivery is on its way.',
      exampleTranslation: 'A entrega está a caminho.',
      audioAsset: 'audio/fase1/som_enganoso/delivery.mp3',
      ipa: '/dɪˈlɪvəri/',
      phonetic: 'di-LÍ-ve-ri',
    ),
    LessonItem(
      text: 'feedback',
      translation: 'retorno / feedback',
      example: 'Can you give me some feedback?',
      exampleTranslation: 'Você pode me dar um feedback?',
      audioAsset: 'audio/fase1/som_enganoso/feedback.mp3',
      ipa: '/ˈfiːdbæk/',
      phonetic: 'FÍD-bék',
    ),
  ],
);

/// Lição 11 — "Uso diferente": palavras que o brasileiro já usa no dia a
/// dia, mas com um significado diferente do inglês original.
const licao11 = Lesson(
  id: 'fase1-licao11',
  title: 'Uso diferente',
  objective: 'Estas palavras existem no seu dia a dia, mas o significado '
      'em inglês não é o que você imagina. Preste atenção no sentido real.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'outdoor',
      translation: 'ao ar livre (não é "painel publicitário")',
      example: 'I love outdoor activities.',
      exampleTranslation: 'Eu amo atividades ao ar livre.',
      audioAsset: 'audio/fase1/uso_diferente/outdoor.mp3',
      ipa: '/ˈaʊtdɔːr/',
      phonetic: 'ÁUT-dor',
    ),
    LessonItem(
      text: 'notebook',
      translation: 'caderno (não é "laptop")',
      example: 'I wrote it in my notebook.',
      exampleTranslation: 'Eu escrevi isso no meu caderno.',
      audioAsset: 'audio/fase1/uso_diferente/notebook.mp3',
      ipa: '/ˈnoʊtbʊk/',
      phonetic: 'NÔUT-buk',
    ),
    LessonItem(
      text: 'shopping',
      translation: 'compras, a ação de comprar (não é "o shopping center")',
      example: "I'm going shopping this afternoon.",
      exampleTranslation: 'Eu vou fazer compras hoje de tarde.',
      audioAsset: 'audio/fase1/uso_diferente/shopping.mp3',
      ipa: '/ˈʃɑːpɪŋ/',
      phonetic: 'CHÓ-pin',
    ),
    LessonItem(
      text: 'home office',
      translation: 'escritório montado em casa',
      example: 'I have a small home office.',
      exampleTranslation: 'Eu tenho um pequeno escritório em casa.',
      audioAsset: 'audio/fase1/uso_diferente/home_office.mp3',
      ipa: '/hoʊm ˈɔːfɪs/',
      phonetic: 'rróum Ó-fis',
    ),
    LessonItem(
      text: 'chips',
      translation: 'batatinhas fritas de pacote (não é o "chip" do celular)',
      example: 'I bought a bag of chips.',
      exampleTranslation: 'Eu comprei um pacote de batatinhas.',
      audioAsset: 'audio/fase1/uso_diferente/chips.mp3',
      ipa: '/tʃɪps/',
      phonetic: 'TCHÍPS',
    ),
  ],
);

/// Lição 12 — "Revisão Bloco 2": uma palavra de cada lição do bloco.
const licao12 = Lesson(
  id: 'fase1-licao12',
  title: 'Revisão de fala — Zona 2',
  objective: 'Uma palavra de cada lição deste bloco — ritmo, sílaba forte '
      'e os sons que mais enganam o ouvido brasileiro.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'job',
      translation: 'emprego / trabalho',
      example: 'I start my new job on Monday.',
      exampleTranslation: 'Eu começo meu novo trabalho na segunda.',
      audioAsset: 'audio/fase1/licao05/job.mp3',
      ipa: '/dʒɑːb/',
      phonetic: 'DJÓB',
    ),
    LessonItem(
      text: 'comfortable',
      translation: 'confortável',
      example: 'Make yourself comfortable.',
      exampleTranslation: 'Fique à vontade.',
      audioAsset: 'audio/fase1/licao06/comfortable.mp3',
      ipa: '/ˈkʌmftərbəl/',
      phonetic: 'CÂMF-ter-bou',
    ),
    LessonItem(
      text: 'business',
      translation: 'negócio / empresa',
      example: "It's a family business.",
      exampleTranslation: 'É um negócio de família.',
      audioAsset: 'audio/fase1/som_enganoso/business.mp3',
      ipa: '/ˈbɪznəs/',
      phonetic: 'BÍZ-nes',
    ),
    LessonItem(
      text: 'shopping',
      translation: 'compras (a ação de comprar)',
      example: 'We went shopping yesterday.',
      exampleTranslation: 'Nós fomos fazer compras ontem.',
      audioAsset: 'audio/fase1/uso_diferente/shopping.mp3',
      ipa: '/ˈʃɑːpɪŋ/',
      phonetic: 'CHÓ-pin',
    ),
  ],
);

/// Lição 13 — BÔNUS Bloco 2 — "Desafio: ritmo avançado". Opcional: não
/// bloqueia a Lição 14 (a progressão olha para a Lição 12, não para esta).
const licao13 = Lesson(
  id: 'fase1-licao13',
  title: 'Desafio: ritmo avançado',
  objective: 'Bônus opcional — palavras mais longas com sílaba forte '
      'traiçoeira. Não precisa fazer para seguir em frente.',
  approvalThreshold: 75,
  minProsody: 70,
  bonus: true,
  items: [
    LessonItem(
      text: 'necessary',
      translation: 'necessário',
      example: 'Water is necessary for life.',
      exampleTranslation: 'Água é necessária para a vida.',
      audioAsset: 'audio/fase1/bonus_ritmo/necessary.mp3',
      ipa: '/ˈnɛsəsɛri/',
      phonetic: 'NÉ-se-se-ri',
    ),
    LessonItem(
      text: 'temperature',
      translation: 'temperatura',
      example: "What's the temperature today?",
      exampleTranslation: 'Qual é a temperatura hoje?',
      audioAsset: 'audio/fase1/bonus_ritmo/temperature.mp3',
      ipa: '/ˈtɛmprətʃər/',
      phonetic: 'TÉM-pre-tcher',
    ),
    LessonItem(
      text: 'government',
      translation: 'governo',
      example: 'The government announced new rules.',
      exampleTranslation: 'O governo anunciou novas regras.',
      audioAsset: 'audio/fase1/bonus_ritmo/government.mp3',
      ipa: '/ˈɡʌvərmənt/',
      phonetic: 'GÂ-ver-ment',
    ),
    LessonItem(
      text: 'photography',
      translation: 'fotografia',
      example: 'Photography is her passion.',
      exampleTranslation: 'Fotografia é a paixão dela.',
      audioAsset: 'audio/fase1/bonus_ritmo/photography.mp3',
      ipa: '/fəˈtɑːɡrəfi/',
      phonetic: 'fo-TÓ-gra-fi',
    ),
    LessonItem(
      text: 'vocabulary',
      translation: 'vocabulário',
      example: 'Reading improves your vocabulary.',
      exampleTranslation: 'Ler melhora seu vocabulário.',
      audioAsset: 'audio/fase1/bonus_ritmo/vocabulary.mp3',
      ipa: '/voʊˈkæbjʊlɛri/',
      phonetic: 'vo-KÉ-biu-le-ri',
    ),
  ],
);

// ---------------------------------------------------------------------------
// BLOCO 3 — Da palavra à frase
// ---------------------------------------------------------------------------

/// Lição 14 — "Primeiros chunks": da palavra isolada à frase curta.
const licao14 = Lesson(
  id: 'fase1-licao14',
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

/// Lição 15 — "Frases de cortesia": comunicação imediata.
const licao15 = Lesson(
  id: 'fase1-licao15',
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

/// Lição 16 — "Pequenos pedidos": fala funcional.
const licao16 = Lesson(
  id: 'fase1-licao16',
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

/// Lição 17 — "Casa e lazer": vocabulário doméstico e de tempo livre.
const licao17 = Lesson(
  id: 'fase1-licao17',
  title: 'Casa e lazer',
  objective: 'Palavras de casa e do tempo livre que você já usa em '
      'português — hora de acertar o som em inglês.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'closet',
      translation: 'armário / guarda-roupa',
      example: 'Put your clothes in the closet.',
      exampleTranslation: 'Coloque suas roupas no armário.',
      audioAsset: 'audio/fase1/casa_lazer/closet.mp3',
      ipa: '/ˈklɑːzət/',
      phonetic: 'KLÓ-zet',
    ),
    LessonItem(
      text: 'freezer',
      translation: 'freezer / congelador',
      example: 'The ice cream is in the freezer.',
      exampleTranslation: 'O sorvete está no freezer.',
      audioAsset: 'audio/fase1/casa_lazer/freezer.mp3',
      ipa: '/ˈfriːzər/',
      phonetic: 'FRÍ-zer',
    ),
    LessonItem(
      text: 'playground',
      translation: 'parquinho',
      example: 'The kids are at the playground.',
      exampleTranslation: 'As crianças estão no parquinho.',
      audioAsset: 'audio/fase1/casa_lazer/playground.mp3',
      ipa: '/ˈpleɪɡraʊnd/',
      phonetic: 'PLÊI-gráund',
    ),
    LessonItem(
      text: 'babysitter',
      translation: 'babá',
      example: 'I need a babysitter tonight.',
      exampleTranslation: 'Eu preciso de uma babá hoje à noite.',
      audioAsset: 'audio/fase1/casa_lazer/babysitter.mp3',
      ipa: '/ˈbeɪbiˌsɪtər/',
      phonetic: 'BÉI-bi-si-ter',
    ),
    LessonItem(
      text: 'happy hour',
      translation: 'happy hour (promoção de bebidas no fim do dia)',
      example: "Let's go for happy hour after work.",
      exampleTranslation: 'Vamos no happy hour depois do trabalho.',
      audioAsset: 'audio/fase1/casa_lazer/happy_hour.mp3',
      ipa: '/ˈhæpi aʊər/',
      phonetic: 'RRÉ-pi áuer',
    ),
  ],
);

/// Lição 18 — "Compras e dinheiro": inglês prático de consumo.
const licao18 = Lesson(
  id: 'fase1-licao18',
  title: 'Compras e dinheiro',
  objective: 'Inglês prático para qualquer loja: pagar, pedir desconto '
      'e usar cupom sem travar.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'cash',
      translation: 'dinheiro (em espécie)',
      example: 'Do you accept cash?',
      exampleTranslation: 'Vocês aceitam dinheiro?',
      audioAsset: 'audio/fase1/compras_dinheiro/cash.mp3',
      ipa: '/kæʃ/',
      phonetic: 'KÉSH',
    ),
    LessonItem(
      text: 'credit card',
      translation: 'cartão de crédito',
      example: "I'll pay with credit card.",
      exampleTranslation: 'Eu vou pagar com cartão de crédito.',
      audioAsset: 'audio/fase1/compras_dinheiro/credit_card.mp3',
      ipa: '/ˈkrɛdɪt kɑːrd/',
      phonetic: 'KRÉ-dit kárd',
    ),
    LessonItem(
      text: 'discount',
      translation: 'desconto',
      example: 'Is there a discount today?',
      exampleTranslation: 'Tem desconto hoje?',
      audioAsset: 'audio/fase1/compras_dinheiro/discount.mp3',
      ipa: '/ˈdɪskaʊnt/',
      phonetic: 'DÍS-káunt',
    ),
    LessonItem(
      text: 'voucher',
      translation: 'vale / cupom',
      example: 'I have a voucher for this store.',
      exampleTranslation: 'Eu tenho um voucher para esta loja.',
      audioAsset: 'audio/fase1/compras_dinheiro/voucher.mp3',
      ipa: '/ˈvaʊtʃər/',
      phonetic: 'VÁU-tcher',
    ),
    LessonItem(
      text: 'cashback',
      translation: 'dinheiro de volta',
      example: 'This app gives cashback on purchases.',
      exampleTranslation: 'Esse aplicativo dá cashback nas compras.',
      audioAsset: 'audio/fase1/compras_dinheiro/cashback.mp3',
      ipa: '/ˈkæʃbæk/',
      phonetic: 'KÉSH-bék',
    ),
  ],
);

/// Lição 19 — "Revisão final": uma palavra de cada lição deste bloco,
/// fecha o básico (Fase 1).
const licao19 = Lesson(
  id: 'fase1-licao19',
  title: 'Revisão de fala — final',
  objective: 'Uma palavra de cada lição deste bloco — feche o básico '
      'vendo o quanto sua fala evoluiu desde a lição 1.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'I like it',
      translation: 'eu gosto (disso)',
      example: 'This food is great. I like it!',
      exampleTranslation: 'Essa comida é ótima. Eu gosto!',
      audioAsset: 'audio/fase1/licao07/I_like_it.mp3',
      ipa: '/aɪ ˈlaɪk ɪt/',
      phonetic: 'ai LÁIK it',
    ),
    LessonItem(
      text: 'Thank you',
      translation: 'obrigado(a)',
      example: 'Thank you for your help.',
      exampleTranslation: 'Obrigado pela sua ajuda.',
      audioAsset: 'audio/fase1/licao08/Thank_you.mp3',
      ipa: '/ˈθæŋk juː/',
      phonetic: 'TÉNK iu',
    ),
    LessonItem(
      text: 'Can I have a coffee?',
      translation: 'Posso pedir um café?',
      example: 'Can I have a coffee, please?',
      exampleTranslation: 'Posso pedir um café, por favor?',
      audioAsset: 'audio/fase1/licao09/Can_I_have_a_coffee.mp3',
      ipa: '/kæn aɪ hæv ə ˈkɔːfi/',
      phonetic: 'ken ai RÉV a CÓ-fi',
    ),
    LessonItem(
      text: 'closet',
      translation: 'armário / guarda-roupa',
      example: 'My closet is full of clothes.',
      exampleTranslation: 'Meu armário está cheio de roupas.',
      audioAsset: 'audio/fase1/casa_lazer/closet.mp3',
      ipa: '/ˈklɑːzət/',
      phonetic: 'KLÓ-zet',
    ),
    LessonItem(
      text: 'cash',
      translation: 'dinheiro (em espécie)',
      example: "I'll pay in cash.",
      exampleTranslation: 'Eu vou pagar em dinheiro.',
      audioAsset: 'audio/fase1/compras_dinheiro/cash.mp3',
      ipa: '/kæʃ/',
      phonetic: 'KÉSH',
    ),
  ],
);

/// Lição 20 — BÔNUS Bloco 3 — "Desafio: pedidos mais longos". Opcional:
/// fecha o básico para quem quer ir além do mínimo.
const licao20 = Lesson(
  id: 'fase1-licao20',
  title: 'Desafio: pedidos mais longos',
  objective: 'Bônus opcional — frases mais longas e educadas para usar em '
      'qualquer loja ou atendimento. Fecha o básico para quem quer mais.',
  approvalThreshold: 75,
  bonus: true,
  items: [
    LessonItem(
      text: 'Could you help me, please',
      translation: 'você poderia me ajudar, por favor?',
      example: 'Excuse me, could you help me, please?',
      exampleTranslation: 'Com licença, você poderia me ajudar, por favor?',
      audioAsset: 'audio/fase1/bonus_pedidos/Could_you_help_me,_please.mp3',
      ipa: '/kʊd ju hɛlp miː pliːz/',
      phonetic: 'kud iu RRÉLP mi plíz',
    ),
    LessonItem(
      text: "I'd like to order a coffee",
      translation: 'eu gostaria de pedir um café',
      example: "I'd like to order a coffee, please.",
      exampleTranslation: 'Eu gostaria de pedir um café, por favor.',
      audioAsset: "audio/fase1/bonus_pedidos/I'd_like_to_order_a_coffee.mp3",
      ipa: '/aɪd laɪk tu ˈɔːrdər ə ˈkɔːfi/',
      phonetic: 'aid LÁIK tu ÓR-der e CÓ-fi',
    ),
    LessonItem(
      text: 'Do you have a discount',
      translation: 'vocês têm desconto?',
      example: 'Do you have a discount for cash?',
      exampleTranslation: 'Vocês têm desconto para pagamento em dinheiro?',
      audioAsset: 'audio/fase1/bonus_pedidos/Do_you_have_a_discount.mp3',
      ipa: '/du ju hæv ə ˈdɪskaʊnt/',
      phonetic: 'du iu rrév e DÍS-kaunt',
    ),
    LessonItem(
      text: 'Where is the restroom',
      translation: 'onde é o banheiro?',
      example: 'Excuse me, where is the restroom?',
      exampleTranslation: 'Com licença, onde é o banheiro?',
      audioAsset: 'audio/fase1/bonus_pedidos/Where_is_the_restroom.mp3',
      ipa: '/wɛr ɪz ðə ˈrɛstruːm/',
      phonetic: 'uér iz de RÉST-rum',
    ),
    LessonItem(
      text: 'Can I get a receipt',
      translation: 'posso pegar um recibo?',
      example: 'Can I get a receipt, please?',
      exampleTranslation: 'Posso pegar um recibo, por favor?',
      audioAsset: 'audio/fase1/bonus_pedidos/Can_I_get_a_receipt.mp3',
      ipa: '/kæn aɪ ɡɛt ə rɪˈsiːt/',
      phonetic: 'ken ai guét e ri-SÍT',
    ),
  ],
);

// ---------------------------------------------------------------------------
// BLOCO 4 — Conversa do dia a dia
// ---------------------------------------------------------------------------

/// Lição 21 — "Variações de How are you?": pergunta de abertura de qualquer
/// conversa, em 5 formas diferentes de soar natural.
const licao21 = Lesson(
  id: 'fase1-licao21',
  title: 'Variações de "How are you?"',
  objective: 'A pergunta que abre toda conversa em inglês, em 5 jeitos '
      'diferentes de perguntar a mesma coisa.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'How are you?',
      translation: 'como você está?',
      example: 'Hi! How are you?',
      exampleTranslation: 'Oi! Como você está?',
      audioAsset: 'audio/fase1/bloco4_saudacoes/How_are_you.mp3',
      ipa: '/haʊ ər juː/',
      phonetic: 'rráu ar iú',
    ),
    LessonItem(
      text: 'How are you doing?',
      translation: 'como você está indo? / como vai?',
      example: 'Hey! How are you doing?',
      exampleTranslation: 'Ei! Como vai?',
      audioAsset: 'audio/fase1/bloco4_saudacoes/How_are_you_doing.mp3',
      ipa: '/haʊ ər juː ˈduːɪŋ/',
      phonetic: 'rráu ar iú DÚ-in',
    ),
    LessonItem(
      text: "How's it going?",
      translation: 'como estão as coisas?',
      example: "Hi, how's it going?",
      exampleTranslation: 'Oi, como estão as coisas?',
      audioAsset: "audio/fase1/bloco4_saudacoes/How's_it_going.mp3",
      ipa: '/haʊz ɪt ˈɡoʊɪŋ/',
      phonetic: 'rráuz it GÔU-in',
    ),
    LessonItem(
      text: 'How have you been?',
      translation: 'como você tem estado?',
      example: "It's been a while. How have you been?",
      exampleTranslation: 'Já faz tempo. Como você tem estado?',
      audioAsset: 'audio/fase1/bloco4_saudacoes/How_have_you_been.mp3',
      ipa: '/haʊ həv juː bɪn/',
      phonetic: 'rráu rrev iú BIN',
    ),
    LessonItem(
      text: "How's your day going?",
      translation: 'como está indo seu dia?',
      example: "Hey! How's your day going?",
      exampleTranslation: 'Ei! Como está indo seu dia?',
      audioAsset: "audio/fase1/bloco4_saudacoes/How's_your_day_going.mp3",
      ipa: '/haʊz jʊr deɪ ˈɡoʊɪŋ/',
      phonetic: 'rráuz iór dêi GÔU-in',
    ),
  ],
);

/// Lição 22 — "Respondendo que está bem": a resposta automática a
/// "How are you?", em 5 variações.
const licao22 = Lesson(
  id: 'fase1-licao22',
  title: 'Respondendo que está bem',
  objective: 'Agora a resposta: 5 jeitos de dizer que você está bem sem '
      'travar.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: "I'm good, thanks.",
      translation: 'estou bem, obrigado(a).',
      example: "How are you? — I'm good, thanks.",
      exampleTranslation: 'Como você está? — Estou bem, obrigado.',
      audioAsset: "audio/fase1/bloco4_respostas/I'm_good,_thanks.mp3",
      ipa: '/aɪm ɡʊd θæŋks/',
      phonetic: 'aim GÚD, ténks',
    ),
    LessonItem(
      text: "I'm doing well.",
      translation: 'estou indo bem.',
      example: "I'm doing well, and you?",
      exampleTranslation: 'Estou indo bem, e você?',
      audioAsset: "audio/fase1/bloco4_respostas/I'm_doing_well.mp3",
      ipa: '/aɪm ˈduːɪŋ wɛl/',
      phonetic: 'aim DÚ-in uél',
    ),
    LessonItem(
      text: "I'm great, thank you.",
      translation: 'estou ótimo, obrigado(a).',
      example: "I'm great, thank you for asking.",
      exampleTranslation: 'Estou ótimo, obrigado por perguntar.',
      audioAsset: "audio/fase1/bloco4_respostas/I'm_great,_thank_you.mp3",
      ipa: '/aɪm ɡreɪt θæŋk juː/',
      phonetic: 'aim GRÊIT, ténk iu',
    ),
    LessonItem(
      text: 'Pretty good, actually.',
      translation: 'bem bom, na verdade.',
      example: 'Pretty good, actually. Thanks for asking.',
      exampleTranslation: 'Bem bom, na verdade. Obrigado por perguntar.',
      audioAsset: 'audio/fase1/bloco4_respostas/Pretty_good,_actually.mp3',
      ipa: '/ˈprɪti ɡʊd ˈæktʃuəli/',
      phonetic: 'PRÍ-ti gud ÉK-chu-a-li',
    ),
    LessonItem(
      text: "I'm feeling good today.",
      translation: 'estou me sentindo bem hoje.',
      example: "I'm feeling good today, thanks.",
      exampleTranslation: 'Estou me sentindo bem hoje, obrigado.',
      audioAsset: "audio/fase1/bloco4_respostas/I'm_feeling_good_today.mp3",
      ipa: '/aɪm ˈfiːlɪŋ ɡʊd təˈdeɪ/',
      phonetic: 'aim FÍ-lin gud tu-DÊI',
    ),
  ],
);

/// Lição 23 — "Falando do dia / weather": small talk sobre o clima, o
/// assunto mais universal de qualquer conversa em inglês.
const licao23 = Lesson(
  id: 'fase1-licao23',
  title: 'Falando do dia / weather',
  objective: 'O assunto mais usado em qualquer conversa pequena em inglês: '
      'o tempo. 5 frases para nunca travar nisso.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: "It's sunny today.",
      translation: 'está ensolarado hoje.',
      example: "It's sunny today, let's go outside.",
      exampleTranslation: 'Está ensolarado hoje, vamos sair.',
      audioAsset: "audio/fase1/bloco4_clima/It's_sunny_today.mp3",
      ipa: '/ɪts ˈsʌni təˈdeɪ/',
      phonetic: 'its SÂ-ni tu-DÊI',
    ),
    LessonItem(
      text: "It's a bit cloudy today.",
      translation: 'está um pouco nublado hoje.',
      example: "It's a bit cloudy today, bring a jacket.",
      exampleTranslation: 'Está um pouco nublado hoje, leve uma jaqueta.',
      audioAsset: "audio/fase1/bloco4_clima/It's_a_bit_cloudy_today.mp3",
      ipa: '/ɪts ə bɪt ˈklaʊdi təˈdeɪ/',
      phonetic: 'its e bit KLÁU-di tu-DÊI',
    ),
    LessonItem(
      text: "It's really hot today.",
      translation: 'está muito calor hoje.',
      example: "It's really hot today, drink some water.",
      exampleTranslation: 'Está muito calor hoje, beba água.',
      audioAsset: "audio/fase1/bloco4_clima/It's_really_hot_today.mp3",
      ipa: '/ɪts ˈrɪli hɑːt təˈdeɪ/',
      phonetic: 'its RÍ-li rrót tu-DÊI',
    ),
    LessonItem(
      text: "It's a little cold today.",
      translation: 'está um pouco frio hoje.',
      example: "It's a little cold today, wear a coat.",
      exampleTranslation: 'Está um pouco frio hoje, use um casaco.',
      audioAsset: "audio/fase1/bloco4_clima/It's_a_little_cold_today.mp3",
      ipa: '/ɪts ə ˈlɪtəl koʊld təˈdeɪ/',
      phonetic: 'its e LÍ-tou kôuld tu-DÊI',
    ),
    LessonItem(
      text: 'The weather is nice today.',
      translation: 'o tempo está bom hoje.',
      example: 'The weather is nice today, perfect for a walk.',
      exampleTranslation: 'O tempo está bom hoje, perfeito pra uma caminhada.',
      audioAsset: 'audio/fase1/bloco4_clima/The_weather_is_nice_today.mp3',
      ipa: '/ðə ˈwɛðər ɪz naɪs təˈdeɪ/',
      phonetic: 'de UÉ-der iz náis tu-DÊI',
    ),
  ],
);

/// Lição 24 — "It's a beautiful day to…": chunk de abertura para convidar
/// alguém a fazer algo, reaproveitando o mesmo molde 5 vezes.
const licao24 = Lesson(
  id: 'fase1-licao24',
  title: '"It\'s a beautiful day to…"',
  objective: 'Um molde só, 5 finais diferentes — assim você fala de um dia '
      'bonito sem decorar frase nova cada vez.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: "It's a beautiful day to go outside.",
      translation: 'é um dia bonito para sair.',
      example: "It's a beautiful day to go outside and relax.",
      exampleTranslation: 'É um dia bonito para sair e relaxar.',
      audioAsset:
          "audio/fase1/bloco4_dia_bonito/It's_a_beautiful_day_to_go_outside.mp3",
      ipa: '/ɪts ə ˈbjuːtəfəl deɪ tu ɡoʊ ˌaʊtˈsaɪd/',
      phonetic: 'its e BIÚ-ti-foul dêi tu gôu áut-sáid',
    ),
    LessonItem(
      text: "It's a beautiful day to have a walk.",
      translation: 'é um dia bonito para dar uma caminhada.',
      example: "Let's go. It's a beautiful day to have a walk.",
      exampleTranslation: 'Vamos. É um dia bonito para dar uma caminhada.',
      audioAsset:
          "audio/fase1/bloco4_dia_bonito/It's_a_beautiful_day_to_have_a_walk.mp3",
      ipa: '/ɪts ə ˈbjuːtəfəl deɪ tu hæv ə wɔːk/',
      phonetic: 'its e BIÚ-ti-foul dêi tu rrév e uók',
    ),
    LessonItem(
      text: "It's a beautiful day to study English.",
      translation: 'é um dia bonito para estudar inglês.',
      example: "It's a beautiful day to study English outside.",
      exampleTranslation: 'É um dia bonito para estudar inglês ao ar livre.',
      audioAsset:
          "audio/fase1/bloco4_dia_bonito/It's_a_beautiful_day_to_study_English.mp3",
      ipa: '/ɪts ə ˈbjuːtəfəl deɪ tu ˈstʌdi ˈɪŋɡlɪʃ/',
      phonetic: 'its e BIÚ-ti-foul dêi tu STÂ-di ÍN-glich',
    ),
    LessonItem(
      text: "It's a beautiful day to drink some coffee.",
      translation: 'é um dia bonito para beber um café.',
      example: "It's a beautiful day to drink some coffee outside.",
      exampleTranslation: 'É um dia bonito para beber um café ao ar livre.',
      audioAsset:
          "audio/fase1/bloco4_dia_bonito/It's_a_beautiful_day_to_drink_some_coffee.mp3",
      ipa: '/ɪts ə ˈbjuːtəfəl deɪ tu drɪŋk səm ˈkɔːfi/',
      phonetic: 'its e BIÚ-ti-foul dêi tu drink sâm CÓ-fi',
    ),
    LessonItem(
      text: "It's a beautiful day to enjoy the morning.",
      translation: 'é um dia bonito para aproveitar a manhã.',
      example: "It's a beautiful day to enjoy the morning with coffee.",
      exampleTranslation: 'É um dia bonito para aproveitar a manhã com café.',
      audioAsset:
          "audio/fase1/bloco4_dia_bonito/It's_a_beautiful_day_to_enjoy_the_morning.mp3",
      ipa: '/ɪts ə ˈbjuːtəfəl deɪ tu ɪnˈdʒɔɪ ðə ˈmɔːrnɪŋ/',
      phonetic: 'its e BIÚ-ti-foul dêi tu in-DJÓI de MÓR-nin',
    ),
  ],
);

/// Lição 25 — "What's the plan…?": pergunta funcional para combinar
/// qualquer atividade, em 5 momentos diferentes do dia/semana.
const licao25 = Lesson(
  id: 'fase1-licao25',
  title: '"What\'s the plan…?"',
  objective: 'A pergunta que organiza qualquer combinação — do café da '
      'manhã ao fim de semana — em 5 momentos diferentes.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: "What's the plan for today?",
      translation: 'qual é o plano para hoje?',
      example: "Good morning! What's the plan for today?",
      exampleTranslation: 'Bom dia! Qual é o plano para hoje?',
      audioAsset: "audio/fase1/bloco4_planos/What's_the_plan_for_today.mp3",
      ipa: '/wʌts ðə plæn fɔːr təˈdeɪ/',
      phonetic: 'uáts de PLÉN for tu-DÊI',
    ),
    LessonItem(
      text: "What's the plan for this morning?",
      translation: 'qual é o plano para esta manhã?',
      example: "What's the plan for this morning? Coffee first?",
      exampleTranslation: 'Qual é o plano para esta manhã? Café primeiro?',
      audioAsset:
          "audio/fase1/bloco4_planos/What's_the_plan_for_this_morning.mp3",
      ipa: '/wʌts ðə plæn fɔːr ðɪs ˈmɔːrnɪŋ/',
      phonetic: 'uáts de PLÉN for dis MÓR-nin',
    ),
    LessonItem(
      text: "What's the plan for the afternoon?",
      translation: 'qual é o plano para a tarde?',
      example: "What's the plan for the afternoon? Do you want to go out?",
      exampleTranslation: 'Qual é o plano para a tarde? Você quer saír?',
      audioAsset:
          "audio/fase1/bloco4_planos/What's_the_plan_for_the_afternoon.mp3",
      ipa: '/wʌts ðə plæn fɔːr ði ˌæftərˈnuːn/',
      phonetic: 'uáts de PLÉN for di éf-ter-NÚN',
    ),
    LessonItem(
      text: "What's the plan after class?",
      translation: 'qual é o plano depois da aula?',
      example: "What's the plan after class today?",
      exampleTranslation: 'Qual é o plano depois da aula hoje?',
      audioAsset: "audio/fase1/bloco4_planos/What's_the_plan_after_class.mp3",
      ipa: '/wʌts ðə plæn ˈæftər klæs/',
      phonetic: 'uáts de PLÉN éf-ter klés',
    ),
    LessonItem(
      text: "What's the plan for the weekend?",
      translation: 'qual é o plano para o fim de semana?',
      example: "It's Friday! What's the plan for the weekend?",
      exampleTranslation: 'É sexta! Qual é o plano para o fim de semana?',
      audioAsset:
          "audio/fase1/bloco4_planos/What's_the_plan_for_the_weekend.mp3",
      ipa: '/wʌts ðə plæn fɔːr ðə ˈwiːkɛnd/',
      phonetic: 'uáts de PLÉN for de UÍK-end',
    ),
  ],
);

/// Lição 26 — "Revisão Bloco 4": uma frase de cada lição do bloco,
/// reaproveitando 100% dos áudios já gerados.
const licao26 = Lesson(
  id: 'fase1-licao26',
  title: 'Revisão de fala — Zona 4',
  objective: 'Uma frase de cada lição que você já fez neste bloco. Veja '
      'como está sua conversa do dia a dia até aqui.',
  approvalThreshold: 75,
  items: [
    LessonItem(
      text: 'How are you?',
      translation: 'como você está?',
      example: "Hey, long time no see! How are you?",
      exampleTranslation: 'Ei, há quanto tempo! Como você está?',
      audioAsset: 'audio/fase1/bloco4_saudacoes/How_are_you.mp3',
      ipa: '/haʊ ər juː/',
      phonetic: 'rráu ar iú',
    ),
    LessonItem(
      text: "I'm doing well.",
      translation: 'estou indo bem.',
      example: "I'm doing well these days.",
      exampleTranslation: 'Estou indo bem nesses dias.',
      audioAsset: "audio/fase1/bloco4_respostas/I'm_doing_well.mp3",
      ipa: '/aɪm ˈduːɪŋ wɛl/',
      phonetic: 'aim DÚ-in uél',
    ),
    LessonItem(
      text: "It's sunny today.",
      translation: 'está ensolarado hoje.',
      example: "Look outside, it's sunny today.",
      exampleTranslation: 'Olha lá fora, está ensolarado hoje.',
      audioAsset: "audio/fase1/bloco4_clima/It's_sunny_today.mp3",
      ipa: '/ɪts ˈsʌni təˈdeɪ/',
      phonetic: 'its SÂ-ni tu-DÊI',
    ),
    LessonItem(
      text: "It's a beautiful day to study English.",
      translation: 'é um dia bonito para estudar inglês.',
      example: "Come on, it's a beautiful day to study English.",
      exampleTranslation: 'Vamos, é um dia bonito para estudar inglês.',
      audioAsset:
          "audio/fase1/bloco4_dia_bonito/It's_a_beautiful_day_to_study_English.mp3",
      ipa: '/ɪts ə ˈbjuːtəfəl deɪ tu ˈstʌdi ˈɪŋɡlɪʃ/',
      phonetic: 'its e BIÚ-ti-foul dêi tu STÂ-di ÍN-glich',
    ),
    LessonItem(
      text: "What's the plan for the weekend?",
      translation: 'qual é o plano para o fim de semana?',
      example: "So, what's the plan for the weekend?",
      exampleTranslation: 'Então, qual é o plano para o fim de semana?',
      audioAsset:
          "audio/fase1/bloco4_planos/What's_the_plan_for_the_weekend.mp3",
      ipa: '/wʌts ðə plæn fɔːr ðə ˈwiːkɛnd/',
      phonetic: 'uáts de PLÉN for de UÍK-end',
    ),
  ],
);

/// Lição 27 — BÔNUS Bloco 4 — "Desafio: conversa mais natural". Opcional:
/// mesmo assunto do bloco (small talk do dia a dia), frases mais longas e
/// naturais. Fecha a Fase 1 para quem quer ir além do básico.
const licao27 = Lesson(
  id: 'fase1-licao27',
  title: 'Desafio: conversa mais natural',
  objective: 'Bônus opcional — o mesmo small talk do bloco, mas em frases '
      'mais longas e naturais. Não precisa fazer para concluir a Fase 1.',
  approvalThreshold: 75,
  bonus: true,
  items: [
    LessonItem(
      text: 'How have you been doing lately?',
      translation: 'como você tem estado ultimamente?',
      example: "Hey! How have you been doing lately?",
      exampleTranslation: 'Ei! Como você tem estado ultimamente?',
      audioAsset:
          'audio/fase1/bloco4_bonus/How_have_you_been_doing_lately.mp3',
      ipa: '/haʊ həv juː bɪn ˈduːɪŋ ˈleɪtli/',
      phonetic: 'rráu rrev iú bin DÚ-in LÊIT-li',
    ),
    LessonItem(
      text: "I've been pretty busy, but I'm good.",
      translation: 'eu tenho estado bem ocupado(a), mas estou bem.',
      example: "I've been pretty busy, but I'm good, thanks.",
      exampleTranslation:
          'Eu tenho estado bem ocupado, mas estou bem, obrigado.',
      audioAsset:
          "audio/fase1/bloco4_bonus/I've_been_pretty_busy,_but_I'm_good.mp3",
      ipa: '/aɪv bɪn ˈprɪti ˈbɪzi bʌt aɪm ɡʊd/',
      phonetic: 'aiv bin PRÍ-ti BÍ-zi bât aim GÚD',
    ),
    LessonItem(
      text: 'It looks like it might rain later.',
      translation: 'parece que vai chover mais tarde.',
      example: 'It looks like it might rain later, bring an umbrella.',
      exampleTranslation: 'Parece que vai chover mais tarde, leve um guarda-chuva.',
      audioAsset: 'audio/fase1/bloco4_bonus/It_looks_like_it_might_rain_later.mp3',
      ipa: '/ɪt lʊks laɪk ɪt maɪt reɪn ˈleɪtər/',
      phonetic: 'it luks láik it máit rêin LÊI-ter',
    ),
    LessonItem(
      text: "It's the perfect day to relax outside.",
      translation: 'é o dia perfeito para relaxar ao ar livre.',
      example: "It's the perfect day to relax outside with a book.",
      exampleTranslation: 'É o dia perfeito para relaxar ao ar livre com um livro.',
      audioAsset:
          "audio/fase1/bloco4_bonus/It's_the_perfect_day_to_relax_outside.mp3",
      ipa: '/ɪts ðə ˈpɜːrfɪkt deɪ tu rɪˈlæks ˌaʊtˈsaɪd/',
      phonetic: 'its de PÉR-fekt dêi tu ri-LÉKS áut-sáid',
    ),
    LessonItem(
      text: 'Do you have any plans for the weekend?',
      translation: 'você tem algum plano para o fim de semana?',
      example: 'Do you have any plans for the weekend? Want to hang out?',
      exampleTranslation:
          'Você tem algum plano para o fim de semana? Quer sair?',
      audioAsset:
          'audio/fase1/bloco4_bonus/Do_you_have_any_plans_for_the_weekend.mp3',
      ipa: '/du ju hæv ˈɛni plænz fɔːr ðə ˈwiːkɛnd/',
      phonetic: 'du iu rrév É-ni plénz for de UÍK-end',
    ),
  ],
);
