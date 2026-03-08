import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ECOCRAFT OFFLINE CRAFT DATABASE
// Covers all 19 classes + combinations + count-aware suggestions
// ─────────────────────────────────────────────────────────────────────────────

class CraftDatabase {
  static CraftDatabase? _instance;
  static CraftDatabase get instance => _instance ??= CraftDatabase._();
  CraftDatabase._();

  // ── Main lookup ───────────────────────────────────────────────────────────
  // Returns at least 5 crafts for any combination of detected objects

  List<CraftIdea> getCrafts(
    Map<String, int> objectCounts, {
    List<String> primaryKeys = const [],
  }) {
    final objects = objectCounts.keys.toList();
    final results = <CraftIdea>[];

    // 1. Combination crafts (multi-item)
    results.addAll(_getCombinationCrafts(objectCounts));

    // 2. Single-item crafts for each detected object
    for (final obj in objects) {
      final count = objectCounts[obj] ?? 1;
      results.addAll(_getSingleCrafts(obj, count));
    }

    // 3. Remove duplicates by title
    final seen = <String>{};
    final unique = results.where((c) => seen.add(c.title)).toList();

    // 3b. Sort so crafts using primary objects come first
    if (primaryKeys.isNotEmpty) {
      unique.sort((a, b) {
        final aHasPrimary = primaryKeys.any(
          (p) =>
              a.title.toLowerCase().contains(p.toLowerCase()) ||
              a.description.toLowerCase().contains(p.toLowerCase()) ||
              a.materials.any((m) => m.toLowerCase().contains(p.toLowerCase())),
        );
        final bHasPrimary = primaryKeys.any(
          (p) =>
              b.title.toLowerCase().contains(p.toLowerCase()) ||
              b.description.toLowerCase().contains(p.toLowerCase()) ||
              b.materials.any((m) => m.toLowerCase().contains(p.toLowerCase())),
        );
        if (aHasPrimary && !bHasPrimary) return -1;
        if (!aHasPrimary && bHasPrimary) return 1;
        return 0;
      });
    }

    // 4. Ensure at least 5 — pad with generic if needed
    if (unique.length < 5) {
      unique.addAll(_genericCrafts(objects));
      final seen2 = <String>{};
      return unique.where((c) => seen2.add(c.title)).take(20).toList();
    }

    return unique.take(20).toList();
  }

  // ── Combination crafts ────────────────────────────────────────────────────

  List<CraftIdea> _getCombinationCrafts(Map<String, int> counts) {
    final has = (String k) => counts.containsKey(k);
    final crafts = <CraftIdea>[];

    // Plastic bottle + cardboard
    if (has('plastic-water-bottle') && has('cardboard')) {
      crafts.add(
        CraftIdea(
          title: 'Bottle & Cardboard Marble Run',
          description:
              'Build an exciting marble run using cut plastic bottles as tubes and cardboard as ramps and supports.',
          steps: [
            'Cut bottles into half-pipe shapes lengthwise',
            'Cut cardboard into ramp strips and support towers',
            'Tape bottle halves at angles to cardboard supports',
            'Connect sections so marbles flow from one to the next',
            'Test with a marble and adjust angles for smooth flow',
          ],
          materials: ['Tape', 'Scissors', 'Marbles or small balls', 'Ruler'],
        ),
      );
      crafts.add(
        CraftIdea(
          title: 'Cardboard & Bottle Desk Organiser',
          description:
              'Combine a cardboard box frame with cut bottle compartments to make a stylish multi-pocket desk organiser.',
          steps: [
            'Cut cardboard into a box frame',
            'Cut bottle bottoms at different heights',
            'Arrange bottles inside the cardboard frame',
            'Glue each bottle in place',
            'Paint or cover with decorative paper',
          ],
          materials: ['Glue', 'Paint', 'Scissors', 'Craft knife'],
        ),
      );
    }

    // Plastic bottle + cloth
    if (has('plastic-water-bottle') && has('cloth')) {
      crafts.add(
        CraftIdea(
          title: 'Fabric-Wrapped Bottle Vase',
          description:
              'Wrap a plastic bottle in colourful fabric scraps to create a beautiful decorative vase.',
          steps: [
            'Clean and dry the bottle',
            'Cut fabric into strips or patches',
            'Apply fabric glue around the bottle',
            'Wrap fabric tightly and smoothly',
            'Add a ribbon or trim around the neck',
          ],
          materials: ['Fabric glue', 'Scissors', 'Ribbon', 'Decorative trim'],
        ),
      );
    }

    // Metal can + cardboard
    if (has('metal-can') && has('cardboard')) {
      crafts.add(
        CraftIdea(
          title: 'Can & Cardboard Robot Toy',
          description:
              'Build a fun articulated robot figure using tin cans as the body and cardboard for limbs.',
          steps: [
            'Use a large can as the body and small cans as head and legs',
            'Cut cardboard strips for arms',
            'Connect parts using wire through punched holes',
            'Paint silver or bright colours',
            'Add cardboard details like buttons and eyes',
          ],
          materials: ['Wire', 'Hammer and nail', 'Paint', 'Glue', 'Markers'],
        ),
      );
    }

    // Cardboard + paper
    if (has('cardboard') && has('paper')) {
      crafts.add(
        CraftIdea(
          title: 'Paper & Cardboard Notebook',
          description:
              'Bind recycled paper sheets between cardboard covers to make a handmade notebook.',
          steps: [
            'Cut cardboard into two equal cover pieces',
            'Stack paper sheets and fold in half',
            'Punch 3 holes along the spine of paper and covers',
            'Thread string or yarn through holes and tie off',
            'Decorate the cover with drawings or collage',
          ],
          materials: [
            'String or yarn',
            'Hole punch or nail',
            'Scissors',
            'Decorative materials',
          ],
        ),
      );
      crafts.add(
        CraftIdea(
          title: 'Cardboard & Paper Wall Art',
          description:
              'Layer torn paper pieces over a cardboard base to create colourful mixed-media wall art.',
          steps: [
            'Cut cardboard to desired frame size',
            'Tear paper into small irregular pieces',
            'Arrange pieces in a pattern or picture on the cardboard',
            'Glue each piece down with PVA glue',
            'Seal the whole surface with a thin layer of PVA',
          ],
          materials: [
            'PVA glue',
            'Paintbrush',
            'Scissors',
            'Paint for background',
          ],
        ),
      );
    }

    // Pen + pencil + ruler + eraser + sharpener (stationery bundle)
    final stationeryCount = [
      'pen',
      'pencil',
      'ruler',
      'eraser',
      'sharpener',
    ].where((s) => has(s)).length;
    if (stationeryCount >= 2) {
      crafts.add(
        CraftIdea(
          title: 'Stationery Sculpture',
          description:
              'Arrange old pens, pencils, rulers and erasers into a quirky desk sculpture or holder.',
          steps: [
            'Gather all stationery items',
            'Arrange them in a pleasing geometric pattern',
            'Bind together tightly with rubber bands or string',
            'Optionally mount on a cardboard or wooden base',
            'Add a label — this is both art and a functional holder',
          ],
          materials: [
            'Rubber bands or string',
            'Cardboard base',
            'Glue',
            'Paint (optional)',
          ],
        ),
      );
      crafts.add(
        CraftIdea(
          title: 'Pen & Pencil Wind Chime',
          description:
              'Hang old pens and pencils from a ruler to create a colourful desktop or window chime.',
          steps: [
            'Punch or drill a small hole near the end of each pen and pencil',
            'Cut string into varying lengths (10-25cm each)',
            'Tie each item to the string',
            'Tie all strings along the ruler at equal spacing',
            'Hang the ruler from two strings at each end',
          ],
          materials: ['String or fishing line', 'Scissors', 'Drill or nail'],
        ),
      );
    }

    // Plastic bag + cloth
    if (has('plastic-bag') && has('cloth')) {
      crafts.add(
        CraftIdea(
          title: 'Fused Plastic & Fabric Tote Bag',
          description:
              'Fuse plastic bags together and combine with fabric strips to make a strong, waterproof tote.',
          steps: [
            'Layer 6 plastic bags between baking parchment',
            'Iron on medium heat (no steam) to fuse layers',
            'Cut fused plastic to bag size',
            'Cut fabric strips for handles',
            'Stitch or staple handles to the fused plastic bag body',
          ],
          materials: [
            'Iron',
            'Baking parchment',
            'Needle and thread or stapler',
            'Scissors',
          ],
        ),
      );
    }

    // Glass bottle + metal can
    if (has('glass-bottle') && has('metal-can')) {
      crafts.add(
        CraftIdea(
          title: 'Bottle & Can Garden Light Set',
          description:
              'Create a matching set of garden lanterns — glass bottle as a tall centrepiece, tin cans as surrounding votives.',
          steps: [
            'Clean all items thoroughly',
            'Punch star or dot patterns in the tin cans (freeze with water first)',
            'Paint or frost the glass bottle',
            'Place LED tea lights inside both',
            'Arrange together as a garden lantern set',
          ],
          materials: [
            'Nails and hammer',
            'Frosting spray',
            'LED tea lights',
            'Paint',
          ],
        ),
      );
    }

    // Aluminium foil + cardboard
    if (has('aluminium-foil') && has('cardboard')) {
      crafts.add(
        CraftIdea(
          title: 'Foil & Cardboard Mirror Frame',
          description:
              'Cover a cardboard frame in crumpled and smoothed aluminium foil to create a shiny decorative mirror surround.',
          steps: [
            'Cut cardboard into a frame shape with a central window',
            'Crumple foil then smooth it flat for texture',
            'Glue foil sheets over the cardboard frame',
            'Press firmly around edges',
            'Mount a small mirror tile or reflective card in the centre',
          ],
          materials: [
            'PVA glue',
            'Small mirror tile',
            'Scissors',
            'Craft knife',
          ],
        ),
      );
      crafts.add(
        CraftIdea(
          title: 'Foil Solar Oven',
          description:
              'Build a simple solar oven from a cardboard box lined with aluminium foil — can actually warm food on a sunny day!',
          steps: [
            'Line the inside of a cardboard box with aluminium foil, shiny side up',
            'Create a flap lid and line it with foil too',
            'Prop the lid open at an angle to reflect sunlight inward',
            'Cover the opening with cling film to trap heat',
            'Place dark container of food inside and aim at the sun',
          ],
          materials: [
            'Cling film',
            'Tape',
            'Black container',
            'Stick to prop lid',
          ],
        ),
      );
    }

    // Cable + phone cover
    if (has('cable') && has('phone-cover')) {
      crafts.add(
        CraftIdea(
          title: 'Cable Art Phone Stand',
          description:
              'Coil and shape old cables into a sculptural phone stand that also doubles as desk art.',
          steps: [
            'Coil a thick cable into a flat circular base',
            'Hot glue the coils to hold the shape',
            'Bend another cable section into a U-shape for the phone rest',
            'Glue the U onto the base at a slight backward angle',
            'Test with your phone and adjust the angle before glue fully sets',
          ],
          materials: ['Hot glue gun', 'Pliers', 'Cable ties'],
        ),
      );
    }

    // Mouse + cable
    if (has('mouse') && has('cable')) {
      crafts.add(
        CraftIdea(
          title: 'Tech Art Wall Piece',
          description:
              'Mount an old computer mouse and cables on a canvas or board as industrial-style tech wall art.',
          steps: [
            'Clean the mouse and cables',
            'Paint a wooden board or canvas in dark colour',
            'Arrange mouse and cables in a visually interesting pattern',
            'Glue or screw components onto the board',
            'Add a frame and label it as art',
          ],
          materials: [
            'Wooden board or canvas',
            'Strong adhesive or screws',
            'Paint',
            'Frame',
          ],
        ),
      );
    }

    // Coconut + any
    if (has('coconut')) {
      crafts.add(
        CraftIdea(
          title: 'Coconut Shell Bowl',
          description:
              'Halve and sand a coconut shell into a beautiful natural serving bowl or decorative dish.',
          steps: [
            'Carefully saw the coconut in half',
            'Remove the flesh and clean the inside thoroughly',
            'Sand the edges smooth with coarse then fine sandpaper',
            'Apply coconut oil or food-safe varnish inside and out',
            'Polish to a shine — use as a bowl, candle holder or decor',
          ],
          materials: [
            'Small saw',
            'Sandpaper (coarse + fine)',
            'Coconut oil or varnish',
            'Cloth for polishing',
          ],
        ),
      );
      crafts.add(
        CraftIdea(
          title: 'Coconut Shell Planter',
          description:
              'Turn a coconut shell half into a charming hanging planter for succulents or air plants.',
          steps: [
            'Clean the coconut shell half',
            'Drill 3 evenly-spaced holes near the rim',
            'Thread twine through each hole and knot underneath',
            'Gather all three twine ends above and tie together',
            'Fill with soil and plant a small succulent or air plant',
          ],
          materials: ['Drill', 'Twine or rope', 'Potting soil', 'Small plant'],
        ),
      );
    }

    // Paper cup + plastic cup
    if (has('paper-cup') && has('plastic-cup')) {
      crafts.add(
        CraftIdea(
          title: 'Cup Tower Game',
          description:
              'Stack and arrange cups of different sizes and materials into a fun stacking or sorting game.',
          steps: [
            'Collect cups of various sizes',
            'Paint each cup a different colour',
            'Number the cups 1 to however many you have',
            'Challenge: stack them in order fastest',
            'Create stacking pattern cards for different challenges',
          ],
          materials: ['Paint', 'Marker', 'Timer'],
        ),
      );
    }

    // Multiple plastic bottles (count > 1)
    if ((counts['plastic-water-bottle'] ?? 0) >= 2) {
      crafts.add(
        CraftIdea(
          title: 'Bottle Greenhouse Cloche',
          description:
              'Cut the bottoms off multiple bottles to make individual plant cloches — mini greenhouses for seedlings.',
          steps: [
            'Cut the base off each bottle cleanly',
            'Remove the cap for ventilation',
            'Push each bottle base-down into the soil over a seedling',
            'The bottle acts as a mini greenhouse protecting from frost',
            'Remove on warm days, replace on cold nights',
          ],
          materials: ['Scissors or craft knife', 'Garden soil', 'Seedlings'],
        ),
      );
      crafts.add(
        CraftIdea(
          title: 'Bottle Xylophone',
          description:
              'Fill multiple bottles with different water levels and tap them to create a playable xylophone.',
          steps: [
            'Line up 6-8 bottles in a row',
            'Fill each with a different amount of water',
            'Add food colouring to each for a rainbow effect',
            'Tap with a pencil or stick to hear different notes',
            'Tune by adding or removing water until you get a musical scale',
          ],
          materials: [
            'Food colouring',
            'Pencil or wooden stick',
            'Measuring cup',
          ],
        ),
      );
    }

    // Multiple metal cans (count > 1)
    if ((counts['metal-can'] ?? 0) >= 2) {
      crafts.add(
        CraftIdea(
          title: 'Multi-Can Herb Garden',
          description:
              'Plant different herbs in a row of matching tin cans for a stylish kitchen herb garden.',
          steps: [
            'Punch drainage holes in the bottom of each can',
            'Paint each can a different colour or matching set',
            'Label each can with the herb name',
            'Fill with potting compost and plant herb seeds',
            'Arrange on a windowsill or hang on a fence rail',
          ],
          materials: [
            'Paint',
            'Marker or chalk labels',
            'Compost',
            'Herb seeds',
            'Nail for holes',
          ],
        ),
      );
    }

    // Sharpener + pencil + eraser
    if (has('sharpener') && has('pencil') && has('eraser')) {
      crafts.add(
        CraftIdea(
          title: 'Stationery Creature Characters',
          description:
              'Glue erasers, sharpeners and pencil stubs together to build funny creature characters.',
          steps: [
            'Lay out all items and imagine creature shapes',
            'Glue eraser as body, sharpener as head',
            'Use pencil stubs as legs',
            'Add googly eyes with a marker or glue',
            'Give each creature a name and display them',
          ],
          materials: [
            'Strong glue',
            'Googly eyes',
            'Markers',
            'Small wire for details',
          ],
        ),
      );
    }

    // Aluminium foil + plastic bottle
    if (has('aluminium-foil') && has('plastic-water-bottle')) {
      crafts.add(
        CraftIdea(
          title: 'DIY Parabolic Solar Charger',
          description:
              'Line a cut bottle with foil to create a parabolic reflector that can focus sunlight to warm or charge small items.',
          steps: [
            'Cut the bottle lengthwise into a curved half',
            'Line the concave side completely with foil, shiny side up',
            'Smooth the foil as flat as possible',
            'Point the reflector at the sun — it focuses light at a point',
            'Place a dark object at the focal point to absorb warmth',
          ],
          materials: [
            'Foil tape or PVA glue',
            'Scissors',
            'Dark-coloured small object',
          ],
        ),
      );
    }

    // Cloth + cardboard
    if (has('cloth') && has('cardboard')) {
      crafts.add(
        CraftIdea(
          title: 'Fabric-Covered Cardboard Storage Box',
          description:
              'Wrap cardboard boxes in fabric to create beautiful matching storage boxes for shelves.',
          steps: [
            'Cut cardboard into a box template and fold into shape',
            'Cut fabric 5cm larger than each face of the box',
            'Apply fabric glue to outside of box',
            'Wrap fabric tightly, folding edges inside neatly',
            'Repeat for the lid',
          ],
          materials: [
            'Fabric glue',
            'Scissors',
            'Ribbon for decoration',
            'Ruler',
          ],
        ),
      );
    }

    // Phone cover + cloth
    if (has('phone-cover') && has('cloth')) {
      crafts.add(
        CraftIdea(
          title: 'Fabric Phone Cover Makeover',
          description:
              'Glue patterned fabric onto an old phone cover to give it a brand new custom look.',
          steps: [
            'Clean the phone cover completely',
            'Cut fabric slightly larger than the cover',
            'Apply fabric glue evenly to the back of the cover',
            'Press fabric down firmly and smooth out bubbles',
            'Trim excess fabric with scissors and seal edges with clear glue',
          ],
          materials: [
            'Fabric glue',
            'Scissors',
            'Clear sealant',
            'Patterned fabric',
          ],
        ),
      );
    }

    // Ruler + cardboard + pen/pencil
    if (has('ruler') && has('cardboard')) {
      crafts.add(
        CraftIdea(
          title: 'Ruler & Cardboard Weaving Loom',
          description:
              'Build a simple weaving loom from rulers and cardboard to weave small fabric patches or coasters.',
          steps: [
            'Cut notches every 1cm along two opposite edges of the cardboard',
            'Thread string through notches to create the warp',
            'Use a ruler as a weaving shuttle to pass weft threads over and under',
            'Push each row tight with the ruler edge',
            'Tie off ends and remove from loom',
          ],
          materials: ['String or yarn', 'Scissors', 'Tape to secure ends'],
        ),
      );
    }

    return crafts;
  }

  // ── Single-item crafts ────────────────────────────────────────────────────

  List<CraftIdea> _getSingleCrafts(String label, int count) {
    switch (label) {
      case 'aluminium-foil':
        return _aluminiumFoilCrafts(count);
      case 'cable':
        return _cableCrafts(count);
      case 'cardboard':
        return _cardboardCrafts(count);
      case 'cloth':
        return _clothCrafts(count);
      case 'coconut':
        return _coconutCrafts(count);
      case 'eraser':
        return _eraserCrafts(count);
      case 'glass-bottle':
        return _glassCrafts(count);
      case 'metal-can':
        return _metalCanCrafts(count);
      case 'mouse':
        return _mouseCrafts(count);
      case 'paper':
        return _paperCrafts(count);
      case 'paper-cup':
        return _paperCupCrafts(count);
      case 'pen':
        return _penCrafts(count);
      case 'pencil':
        return _pencilCrafts(count);
      case 'phone-cover':
        return _phoneCoverCrafts(count);
      case 'plastic-bag':
        return _plasticBagCrafts(count);
      case 'plastic-cup':
        return _plasticCupCrafts(count);
      case 'plastic-water-bottle':
        return _plasticBottleCrafts(count);
      case 'ruler':
        return _rulerCrafts(count);
      case 'sharpener':
        return _sharpenerCrafts(count);
      default:
        return _genericCrafts([label]);
    }
  }

  // ── Per-item craft lists ───────────────────────────────────────────────────

  List<CraftIdea> _aluminiumFoilCrafts(int count) => [
    CraftIdea(
      title: 'Foil Embossed Art',
      description:
          'Press aluminium foil over textured surfaces to create beautiful embossed metallic artworks.',
      steps: [
        'Place foil shiny side down over a textured surface (leaves, coins, lace)',
        'Gently rub a soft cloth over the foil to pick up the texture',
        'Carefully peel the foil off',
        'Mount on dark card for display',
        'Repeat with different textures and arrange in a grid',
      ],
      materials: ['Dark card', 'Soft cloth', 'PVA glue', 'Frame'],
    ),
    CraftIdea(
      title: 'Foil Jewellery',
      description:
          'Scrunch and shape aluminium foil into beads, pendants and bangles for wearable upcycled jewellery.',
      steps: [
        'Tear foil into strips of various widths',
        'Roll strips tightly into bead shapes',
        'Shape some strips around a pencil for ring shapes',
        'Flatten others into pendant shapes and punch holes',
        'Thread onto string or wire',
      ],
      materials: [
        'String or wire',
        'Hole punch',
        'Clear varnish',
        'Jump rings',
      ],
    ),
    CraftIdea(
      title: 'Foil Wind Spinner',
      description:
          'Cut and twist foil strips into a reflective spinning mobile that catches sunlight beautifully.',
      steps: [
        'Cut foil into long strips 3cm wide',
        'Twist each strip along its length',
        'Tie multiple strips to a horizontal stick at varying lengths',
        'Curl the ends of each strip around a pencil',
        'Hang outside where breeze will spin them',
      ],
      materials: ['String', 'Wooden stick', 'Scissors'],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Foil Mosaic Picture',
        description:
            'Tear multiple foil sheets into small pieces and arrange them into a mosaic image on dark cardboard.',
        steps: [
          'Draw your design lightly on dark cardboard',
          'Tear foil into small irregular pieces',
          'Scrunch some pieces for texture variety',
          'Glue pieces onto the design leaving small gaps',
          'Seal with diluted PVA glue',
        ],
        materials: [
          'Dark cardboard',
          'PVA glue',
          'Paintbrush',
          'Marker for outline',
        ],
      ),
  ];

  List<CraftIdea> _cableCrafts(int count) => [
    CraftIdea(
      title: 'Cable Coil Bowl',
      description:
          'Coil old cables into a neat bowl shape — surprisingly sturdy and totally unique.',
      steps: [
        'Start coiling the cable tightly from the centre',
        'Apply hot glue between each coil as you go',
        'Build up the sides by coiling upward at a slight angle',
        'Hold shape until glue cools (30 seconds each section)',
        'Let fully cool before use',
      ],
      materials: ['Hot glue gun', 'Scissors', 'Bowl as mould (optional)'],
    ),
    CraftIdea(
      title: 'Cable Wrapped Vase',
      description:
          'Wind cables around a glass bottle or jar to create an industrial-chic vase.',
      steps: [
        'Clean the bottle or jar',
        'Apply hot glue to the bottom of the bottle',
        'Start wrapping the cable tightly from the bottom up',
        'Glue every few rows to keep it in place',
        'Continue to the top and cut cable neatly',
      ],
      materials: ['Hot glue gun', 'Glass jar or bottle', 'Scissors'],
    ),
    CraftIdea(
      title: 'Cable Basket',
      description:
          'Weave or coil multiple cables into a functional storage basket for your desk.',
      steps: [
        'Lay out cables in parallel strips for the base',
        'Weave perpendicular cables over and under',
        'Fold up the edges to form the basket sides',
        'Weave more cables around the sides horizontally',
        'Secure all ends with cable ties or hot glue',
      ],
      materials: ['Cable ties', 'Hot glue gun', 'Scissors', 'Pliers'],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Cable Macramé Wall Hanging',
        description:
            'Use multiple cables as chunky macramé cord to knot a bold industrial wall hanging.',
        steps: [
          'Cut cables to equal lengths (4× desired finished length)',
          'Fold each cable in half and attach to a dowel with a larks head knot',
          'Work square knots across all cables',
          'Create patterns with alternating square knots',
          'Trim ends evenly and hang on wall',
        ],
        materials: ['Wooden dowel', 'Scissors', 'String to hang dowel'],
      ),
  ];

  List<CraftIdea> _cardboardCrafts(int count) => [
    CraftIdea(
      title: 'Cardboard Desk Organiser',
      description:
          'Build a custom multi-compartment desk organiser perfectly sized for your stationery.',
      steps: [
        'Cut cardboard into panels of the right heights',
        'Score fold lines with a ruler and knife',
        'Assemble compartments by slotting panels together',
        'Reinforce corners with cardboard strips and glue',
        'Cover with wrapping paper or paint to finish',
      ],
      materials: ['Craft knife', 'Ruler', 'White glue', 'Decorative paper'],
    ),
    CraftIdea(
      title: 'Cardboard Bookshelf',
      description:
          'Stack and glue multiple cardboard layers to build a surprisingly strong mini bookshelf.',
      steps: [
        'Cut identical rectangles for shelves',
        'Cut side panels and back panel',
        'Glue and tape all joints carefully',
        'Reinforce with extra cardboard strips inside corners',
        'Paint with 2-3 coats of paint for a clean finish',
      ],
      materials: ['Craft knife', 'Strong glue', 'Paint', 'Ruler'],
    ),
    CraftIdea(
      title: 'Cardboard Geometric Wall Art',
      description:
          'Cut cardboard into geometric shapes and arrange them in a 3D wall sculpture.',
      steps: [
        'Draw and cut various geometric shapes: triangles, hexagons, diamonds',
        'Score and fold some shapes for 3D effect',
        'Paint shapes in coordinated colours',
        'Arrange on wall with mounting putty before committing',
        'Stick permanently once happy with arrangement',
      ],
      materials: ['Paint', 'Mounting putty', 'Craft knife', 'Ruler'],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Cardboard Puppet Theatre',
        description:
            'Build a full puppet theatre with stage and curtains from multiple cardboard boxes.',
        steps: [
          'Join two large boxes end-to-end for the stage opening',
          'Cut a rectangular window for the stage',
          'Add cardboard arch and columns as decoration',
          'Hang fabric scraps as curtains inside',
          'Paint the whole theatre bright colours and perform a show',
        ],
        materials: [
          'Tape',
          'Paint',
          'Fabric scraps',
          'String for curtain rail',
        ],
      ),
    if (count >= 3)
      CraftIdea(
        title: 'Cardboard Maze',
        description:
            'Build an intricate tabletop maze from strips of cardboard — add a marble and race the clock!',
        steps: [
          'Cut a large flat base from one cardboard sheet',
          'Cut long thin strips 4cm wide for walls',
          'Glue walls upright onto the base in a maze pattern',
          'Add a start and finish marker',
          'Tilt the board to roll a marble through the maze',
        ],
        materials: ['Glue', 'Scissors', 'Marble', 'Paint or markers'],
      ),
  ];

  List<CraftIdea> _clothCrafts(int count) => [
    CraftIdea(
      title: 'No-Sew T-Shirt Tote Bag',
      description:
          'Transform a piece of cloth or old T-shirt into a reusable tote bag in under 10 minutes — no sewing needed.',
      steps: [
        'Cut cloth into a rectangle twice as tall as desired bag height',
        'Fold in half with the "outside" facing in',
        'Cut fringe along the bottom edge (3cm strips)',
        'Tie each front and back fringe pair together tightly',
        'Cut handles from the top and knot ends',
      ],
      materials: ['Scissors'],
    ),
    CraftIdea(
      title: 'Fabric Scrap Rug',
      description:
          'Braid fabric strips into a colourful circular rug — great for bathrooms or beside the bed.',
      steps: [
        'Cut fabric into 3cm wide strips',
        'Join strips end to end to make 3 long strands',
        'Braid the 3 strands together tightly',
        'Coil the braid into a flat oval or circle',
        'Stitch coils together with strong thread and large needle',
      ],
      materials: ['Scissors', 'Strong thread', 'Large needle', 'Safety pins'],
    ),
    CraftIdea(
      title: 'Cloth Lavender Sachet',
      description:
          'Sew or tie small fabric pouches and fill with dried lavender or rice for a natural drawer freshener.',
      steps: [
        'Cut fabric into 15×30cm rectangles',
        'Fold in half and stitch 2 sides closed (or glue)',
        'Turn right side out',
        'Fill with lavender, dried herbs or scented rice',
        'Tie the top closed with a ribbon',
      ],
      materials: [
        'Needle and thread or fabric glue',
        'Ribbon',
        'Lavender or scented filling',
      ],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Patchwork Cushion Cover',
        description:
            'Sew together different fabric scraps in a patchwork pattern to make a unique cushion cover.',
        steps: [
          'Cut fabrics into equal squares (10×10cm)',
          'Arrange squares in a pleasing pattern',
          'Sew or glue squares together in rows',
          'Join rows together to form front panel',
          'Sew back panel on 3 sides, insert cushion pad, stitch closed',
        ],
        materials: ['Needle and thread', 'Cushion pad', 'Scissors', 'Pins'],
      ),
  ];

  List<CraftIdea> _coconutCrafts(int count) => [
    CraftIdea(
      title: 'Coconut Shell Candle',
      description:
          'Pour scented wax into a cleaned coconut shell half to make a beautiful natural candle.',
      steps: [
        'Saw coconut in half and clean out the flesh thoroughly',
        'Sand the rim smooth',
        'Centre a candle wick inside using a stick across the top',
        'Melt candle wax and add fragrance oil',
        'Pour wax in and let set for 6 hours before trimming wick',
      ],
      materials: [
        'Small saw',
        'Sandpaper',
        'Candle wick',
        'Wax',
        'Fragrance oil',
      ],
    ),
    CraftIdea(
      title: 'Coconut Shell Bird Feeder',
      description:
          'Hang a coconut shell half filled with bird food as a natural garden bird feeder.',
      steps: [
        'Clean the coconut shell half',
        'Drill 3 holes near the rim',
        'Thread rope through each hole',
        'Gather ropes above and tie together for hanging',
        'Fill with bird seed, suet or fruit pieces and hang from a tree',
      ],
      materials: ['Drill', 'Rope or twine', 'Bird seed or suet'],
    ),
    CraftIdea(
      title: 'Coconut Shell Trinket Bowl',
      description:
          'Sand and varnish a coconut shell half into a beautiful jewellery or trinket dish.',
      steps: [
        'Clean coconut shell completely',
        'Sand inside and outside from coarse to fine grit',
        'Wipe dust away with a damp cloth',
        'Apply 2 coats of clear varnish, sanding lightly between coats',
        'Optionally paint the outside with patterns before varnishing',
      ],
      materials: [
        'Sandpaper (coarse + fine)',
        'Clear varnish',
        'Paintbrush',
        'Paint (optional)',
      ],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Coconut Shell Percussion Instrument',
        description:
            'Tap two coconut shell halves together to make traditional rhythm percussion instruments.',
        steps: [
          'Saw 2 coconuts in half (giving 4 halves)',
          'Clean and dry all halves',
          'Sand the edges smooth',
          'Varnish for durability',
          'Hold one in each hand and click together for horse-hoof rhythm sounds',
        ],
        materials: ['Saw', 'Sandpaper', 'Varnish'],
      ),
  ];

  List<CraftIdea> _eraserCrafts(int count) => [
    CraftIdea(
      title: 'Eraser Stamp Art',
      description:
          'Carve designs into erasers to make custom rubber stamps for cards, wrapping paper and fabric.',
      steps: [
        'Draw your design on the eraser with a pencil',
        'Carve away the background using a craft knife or lino tool',
        'The raised design is your stamp',
        'Press onto an ink pad or paint',
        'Stamp onto paper, card or fabric',
      ],
      materials: [
        'Craft knife or lino carving tool',
        'Ink pad or paint',
        'Paper or fabric to stamp',
      ],
    ),
    CraftIdea(
      title: 'Eraser Mosaic Artwork',
      description:
          'Cut erasers into small pieces and arrange them in a mosaic pattern on a canvas.',
      steps: [
        'Cut erasers into small cubes and irregular pieces',
        'Paint pieces in various colours',
        'Arrange on canvas or card in a pattern or picture',
        'Glue each piece down firmly',
        'Fill gaps with paint if desired',
      ],
      materials: ['Craft knife', 'Paint', 'Canvas or card', 'Strong glue'],
    ),
    CraftIdea(
      title: 'Eraser Jewellery',
      description:
          'Carve erasers into small pendant and charm shapes for lightweight, colourful jewellery.',
      steps: [
        'Sketch a pendant shape on the eraser',
        'Cut out the shape with a craft knife',
        'Carve surface details',
        'Paint in bright colours',
        'Pierce a hole at the top and thread onto a necklace cord',
      ],
      materials: [
        'Craft knife',
        'Paint',
        'Necklace cord',
        'Jump ring',
        'Drill or thick needle for hole',
      ],
    ),
  ];

  List<CraftIdea> _glassCrafts(int count) => [
    CraftIdea(
      title: 'Glass Bottle Terrarium',
      description:
          'Build a sealed miniature garden inside a glass bottle — a self-sustaining tiny ecosystem.',
      steps: [
        'Add 3cm of small pebbles to the bottle for drainage',
        'Add a thin layer of activated charcoal',
        'Add 5cm of potting mix',
        'Use long tweezers to plant small ferns, moss or succulents',
        'Mist lightly, seal with cork and place in indirect light',
      ],
      materials: [
        'Pebbles',
        'Activated charcoal',
        'Potting mix',
        'Small plants',
        'Long tweezers',
      ],
    ),
    CraftIdea(
      title: 'Bottle Fairy Light Lantern',
      description:
          'Drop LED fairy lights into a glass bottle for a magical glowing room decoration.',
      steps: [
        'Clean and dry the bottle completely',
        'Insert a string of battery LED lights through the neck',
        'Arrange lights evenly inside',
        'Leave the battery pack outside the bottle',
        'Display on a shelf or windowsill',
      ],
      materials: ['Battery LED fairy lights', 'String if hanging'],
    ),
    CraftIdea(
      title: 'Etched Glass Bottle Vase',
      description:
          'Apply etching cream to a glass bottle to create a frosted pattern — looks professional and expensive.',
      steps: [
        'Clean bottle thoroughly',
        'Apply sticker or tape in your desired pattern/shape',
        'Apply glass etching cream over the exposed glass',
        'Wait 5 minutes then rinse off thoroughly',
        'Peel sticker to reveal the crisp etched design',
      ],
      materials: [
        'Glass etching cream',
        'Stickers or tape',
        'Rubber gloves',
        'Running water nearby',
      ],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Bottle Wind Chime',
        description:
            'Hang multiple glass bottles at different heights on a branch to create a melodic wind chime.',
        steps: [
          'Clean all bottles',
          'Tie string around the neck of each bottle',
          'Tie bottles to a horizontal driftwood branch at varying lengths',
          'Add a small metal washer inside each bottle for extra chime',
          'Hang outdoors where the breeze will knock bottles together',
        ],
        materials: [
          'String',
          'Driftwood or wooden stick',
          'Small washers',
          'Drill for hanging',
        ],
      ),
  ];

  List<CraftIdea> _metalCanCrafts(int count) => [
    CraftIdea(
      title: 'Tin Can Lantern',
      description:
          'Punch star patterns into tin cans to make beautiful flickering candle lanterns for any occasion.',
      steps: [
        'Fill can with water and freeze overnight so it keeps its shape',
        'Draw pattern on the can with marker',
        'Use nail and hammer to punch holes along the pattern',
        'Let ice melt fully and dry the can',
        'Place a tea light inside for a magical glow',
      ],
      materials: ['Nail', 'Hammer', 'Tea light candle', 'Marker pen'],
    ),
    CraftIdea(
      title: 'Can Pencil Holder',
      description:
          'Wrap tin cans in twine, fabric or washi tape to create a stylish desk organiser.',
      steps: [
        'File any sharp rim edges smooth',
        'Clean and dry the can',
        'Wrap tightly in twine with hot glue between rows',
        'Alternatively wrap in a strip of patterned fabric',
        'Add a ribbon or label to personalise',
      ],
      materials: ['Twine or fabric', 'Hot glue gun', 'Ribbon', 'Metal file'],
    ),
    CraftIdea(
      title: 'Can Herb Planter',
      description:
          'Plant herbs in decorated tin cans for a cute kitchen windowsill garden.',
      steps: [
        'Punch 3 drainage holes in the can bottom',
        'Paint the outside with exterior paint',
        'Add herb name with a paint pen or label',
        'Fill with potting compost',
        'Plant herb seedling and water gently',
      ],
      materials: [
        'Nail for holes',
        'Exterior paint',
        'Potting compost',
        'Herb seedlings',
      ],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Can Xylophone',
        description:
            'Fill cans with different water levels and tap to produce musical notes — a real playable instrument!',
        steps: [
          'Line up cans in a row',
          'Fill each with increasing amounts of water',
          'Add food colouring for a rainbow effect',
          'Tap each can with a metal spoon',
          'Adjust water levels until you get a musical scale',
        ],
        materials: ['Food colouring', 'Metal spoon', 'Measuring cup'],
      ),
    if (count >= 3)
      CraftIdea(
        title: 'Can City Skyline',
        description:
            'Arrange cans of different sizes to represent a city skyline as a decorative display.',
        steps: [
          'Paint each can to look like a building — add windows with marker',
          'Cut some cans shorter for variety',
          'Create a base from cardboard painted as a road',
          'Arrange cans as buildings on the base',
          'Add small paper trees and vehicles to complete the scene',
        ],
        materials: ['Paint', 'Markers', 'Cardboard base', 'Scissors'],
      ),
  ];

  List<CraftIdea> _mouseCrafts(int count) => [
    CraftIdea(
      title: 'Mouse Rock Planter',
      description:
          'Open the mouse casing and fill it with soil and a small succulent for a quirky desk planter.',
      steps: [
        'Open the mouse with a screwdriver',
        'Remove all electronics safely',
        'Line the inside with a small plastic bag pierced for drainage',
        'Fill with succulent potting mix',
        'Plant a small cactus or succulent and place on desk',
      ],
      materials: [
        'Screwdriver',
        'Small plastic bag',
        'Succulent potting mix',
        'Small cactus or succulent',
      ],
    ),
    CraftIdea(
      title: 'Mouse Cable Art Sculpture',
      description:
          'Mount a mouse with its original cable on a plinth as an ironic piece of retro tech art.',
      steps: [
        'Clean the mouse inside and out',
        'Paint or spray the mouse a metallic or bold colour',
        'Coil the cable artfully around the mouse',
        'Glue onto a small wooden block or plinth',
        'Add a handwritten "artwork title" label',
      ],
      materials: [
        'Paint or spray paint',
        'Wooden block',
        'Strong glue',
        'Label card',
      ],
    ),
    CraftIdea(
      title: 'Mouse Night Light',
      description:
          'Install a small LED inside a mouse shell to turn it into a unique nightlight.',
      steps: [
        'Open the mouse and remove all internal components',
        'Sand interior edges smooth',
        'Fit a small battery-powered LED light inside',
        'Close the mouse — light will glow through the scroll wheel or seams',
        'Optionally drill small holes in pattern for light to shine through',
      ],
      materials: [
        'Screwdriver',
        'Small LED light with battery',
        'Drill (optional)',
        'Sandpaper',
      ],
    ),
  ];

  List<CraftIdea> _paperCrafts(int count) => [
    CraftIdea(
      title: 'Paper Bead Jewellery',
      description:
          'Roll strips of coloured or magazine paper into beautiful beads for bracelets and necklaces.',
      steps: [
        'Cut paper into long thin triangles 2cm wide at base',
        'Apply a thin line of glue along the strip',
        'Roll tightly around a toothpick from the wide end',
        'Slide off carefully and let dry',
        'Varnish and thread onto elastic cord',
      ],
      materials: ['Toothpicks', 'PVA glue', 'Elastic cord', 'Clear varnish'],
    ),
    CraftIdea(
      title: 'Origami Gift Boxes',
      description:
          'Fold sheets of paper into origami boxes of different sizes — perfect for gift-giving.',
      steps: [
        'Cut paper into a perfect square',
        'Fold diagonally both ways then unfold',
        'Fold all four corners to the centre',
        'Fold the top and bottom edges to the centre',
        'Open out the sides and shape into a box',
      ],
      materials: ['Scissors', 'Ruler'],
    ),
    CraftIdea(
      title: 'Paper Newspaper Basket',
      description:
          'Weave newspaper strips into a surprisingly strong decorative basket.',
      steps: [
        'Roll each sheet tightly into a long thin tube',
        'Arrange 8 tubes as spokes radiating from a centre',
        'Weave more tubes over and under the spokes in a circle',
        'Continue weaving upward to form the sides',
        'Fold spokes inward to finish the rim',
      ],
      materials: ['PVA glue', 'Tape', 'Clothespegs', 'Varnish or paint'],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Paper Mache Bowl',
        description:
            'Layer strips of paper soaked in paste over a bowl mould to create a custom papier mâché dish.',
        steps: [
          'Mix flour and water into a smooth paste',
          'Tear paper into strips 2cm wide',
          'Dip each strip in paste and layer over the outside of an upturned bowl',
          'Apply 5-6 layers, drying between each pair of layers',
          'Remove from mould, trim edges, paint and varnish',
        ],
        materials: [
          'Flour',
          'Water',
          'Bowl as mould',
          'Petroleum jelly (to stop sticking)',
          'Paint',
          'Varnish',
        ],
      ),
  ];

  List<CraftIdea> _paperCupCrafts(int count) => [
    CraftIdea(
      title: 'Paper Cup Flower Bouquet',
      description:
          'Cut paper cups into flowers and arrange them into a colourful never-wilting bouquet.',
      steps: [
        'Cut vertical slits around the cup from rim to base creating petals',
        'Gently bend petals outward',
        'Paint each flower a different colour',
        'Push a straw or stick through the base as a stem',
        'Wrap stems together with ribbon for a bouquet',
      ],
      materials: ['Scissors', 'Paint', 'Straws or sticks', 'Ribbon'],
    ),
    CraftIdea(
      title: 'Paper Cup Telephone',
      description:
          'The classic paper cup telephone — string two cups together and actually talk through them!',
      steps: [
        'Poke a small hole in the centre of each cup base',
        'Thread string through each hole',
        'Tie a large knot inside each cup to secure the string',
        'Pull string tight between the two cups',
        'Take turns speaking and listening — sound travels along the string!',
      ],
      materials: ['String (at least 5 metres)', 'Pencil to poke holes'],
    ),
    CraftIdea(
      title: 'Paper Cup Seed Starters',
      description:
          'Use paper cups as biodegradable pots to start seedlings that can be planted directly into the ground.',
      steps: [
        'Poke 3 drainage holes in the base',
        'Fill with seed-starting compost',
        'Plant 1-2 seeds per cup',
        'Water gently and place in sunlight',
        'When seedlings are strong, plant the whole cup in the ground — it biodegrades!',
      ],
      materials: ['Compost', 'Seeds', 'Pencil for holes'],
    ),
    if (count >= 3)
      CraftIdea(
        title: 'Paper Cup Stacking Tower Game',
        description:
            'Paint cups in patterns and challenge friends to stack them into towers as quickly as possible.',
        steps: [
          'Paint each cup a different colour or pattern',
          'Number cups on the base',
          'Create stacking challenge cards (e.g. stack by colour, by number)',
          'Set a timer and race',
          'Try building pyramids, towers and other structures',
        ],
        materials: ['Paint', 'Marker', 'Timer'],
      ),
  ];

  List<CraftIdea> _penCrafts(int count) => [
    CraftIdea(
      title: 'Pen Cap Mosaic Frame',
      description:
          'Glue pen caps in rows onto a cardboard frame to make a colourful mosaic picture frame.',
      steps: [
        'Collect pen caps of various colours',
        'Cut cardboard into a frame shape',
        'Arrange caps in colour patterns across the frame',
        'Glue each cap firmly in place',
        'Let dry completely and add your photo',
      ],
      materials: ['Cardboard', 'Strong glue', 'Photo'],
    ),
    CraftIdea(
      title: 'Pen Stem Plant Markers',
      description:
          'Write plant names on cut paper and push into pots using pen bodies as plant marker sticks.',
      steps: [
        'Cut small flag shapes from card or paper',
        'Write the plant name on each flag',
        'Tape or glue each flag to the end of a pen',
        'Push the pen clip-end into the soil of each pot',
        'The flags flutter in the breeze and label your plants clearly',
      ],
      materials: ['Card scraps', 'Tape', 'Scissors'],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Pen Raft Sculpture',
        description:
            'Bind multiple pens together into a floating raft shape — a fun physics experiment and desk toy.',
        steps: [
          'Arrange pens in a rectangle pattern',
          'Bind tightly with rubber bands at each end',
          'Add cross-pieces of pens for stability',
          'Test in a basin of water — it should float!',
          'Decorate with a small paper sail',
        ],
        materials: ['Rubber bands', 'Paper', 'Toothpick for mast'],
      ),
  ];

  List<CraftIdea> _pencilCrafts(int count) => [
    CraftIdea(
      title: 'Pencil Stub Photo Frame',
      description:
          'Glue pencil stubs around a cardboard frame to create a colourful mosaic photo frame.',
      steps: [
        'Cut cardboard into a picture frame shape',
        'Cut pencil stubs into 1cm sections',
        'Arrange sections upright on the frame surface',
        'Glue each piece firmly',
        'Let dry and add your favourite photo',
      ],
      materials: [
        'Cardboard',
        'Strong glue',
        'Craft knife to cut pencil stubs',
      ],
    ),
    CraftIdea(
      title: 'Pencil Wind Chime',
      description:
          'Hang pencil stubs on strings from a ruler or stick for a colourful musical mobile.',
      steps: [
        'Tie string around each pencil near the eraser end',
        'Tie all strings to a horizontal ruler at different lengths',
        'Hang the ruler from two more strings at each end',
        'Space pencils so they can swing and knock together',
        'Hang near an open window',
      ],
      materials: ['String', 'Ruler or stick'],
    ),
    if (count >= 3)
      CraftIdea(
        title: 'Pencil Raft or Cabin Model',
        description:
            'Build a miniature log-cabin or raft model using pencil stubs as the "logs".',
        steps: [
          'Sort pencil stubs into equal lengths',
          'Apply wood glue at the end of each pencil',
          'Stack pencils alternating direction like log cabin walls',
          'Build up 4-5 layers per wall',
          'Add a cardboard roof painted to look like shingles',
        ],
        materials: ['Wood glue', 'Cardboard for roof', 'Paint'],
      ),
  ];

  List<CraftIdea> _phoneCoverCrafts(int count) => [
    CraftIdea(
      title: 'Phone Cover Mosaic Art',
      description:
          'Break an old phone cover into pieces and use them as tiles in a mosaic artwork.',
      steps: [
        'Carefully break the cover into small irregular pieces',
        'Arrange pieces on a cardboard base in a pattern',
        'Glue pieces down leaving small gaps between them',
        'Fill gaps with grout or coloured filler',
        'Seal with varnish when dry',
      ],
      materials: [
        'Cardboard base',
        'Strong adhesive',
        'Grout or filler',
        'Varnish',
      ],
    ),
    CraftIdea(
      title: 'Phone Cover Trinket Tray',
      description:
          'Decorate an old phone cover with paint and gems to repurpose it as a mini jewellery tray.',
      steps: [
        'Clean the phone cover',
        'Paint with acrylic paint in your chosen colour',
        'Add gems, stickers or patterns while paint is still wet',
        'Let dry and apply clear varnish',
        'Use as a ring or small jewellery holder on your dresser',
      ],
      materials: ['Acrylic paint', 'Gems or stickers', 'Clear varnish'],
    ),
    CraftIdea(
      title: 'Phone Cover Keychain',
      description:
          'Cut a small decorative piece from an old phone cover and attach a keyring to make a unique keychain.',
      steps: [
        'Cut an interesting shaped piece from the cover',
        'Sand the cut edges smooth',
        'Drill a small hole at the top',
        'Thread a jump ring through the hole',
        'Attach a keyring clasp and clip to your keys',
      ],
      materials: [
        'Scissors or craft knife',
        'Sandpaper',
        'Drill',
        'Jump ring',
        'Keyring clasp',
      ],
    ),
  ];

  List<CraftIdea> _plasticBagCrafts(int count) => [
    CraftIdea(
      title: 'Plarn Crochet Bag',
      description:
          'Cut plastic bags into strips (plarn) and crochet them into a durable waterproof shopping bag.',
      steps: [
        'Flatten and fold each bag lengthwise into thirds',
        'Cut across into 3cm loops',
        'Link loops together into a continuous strand',
        'Use a 10mm crochet hook to crochet a foundation chain',
        'Single crochet in rounds until bag is the right size, then add handles',
      ],
      materials: [
        'Large crochet hook (10mm+)',
        'Scissors',
        '20+ bags for one tote',
      ],
    ),
    CraftIdea(
      title: 'Fused Plastic Sheet',
      description:
          'Fuse multiple plastic bags into a thick, leather-like sheet that can be sewn or cut into useful items.',
      steps: [
        'Stack 6-8 bags flat between two sheets of baking parchment',
        'Iron on medium heat (no steam) pressing firmly',
        'Check every 30 seconds — stop when fused but not melted',
        'Peel off parchment and let cool flat',
        'Cut into wallet, pencil case or any shape you need',
      ],
      materials: ['Iron', 'Baking parchment', 'Scissors'],
    ),
    if (count >= 3)
      CraftIdea(
        title: 'Plastic Bag Jump Rope',
        description:
            'Braid plastic bag strips into a strong, lightweight jump rope.',
        steps: [
          'Cut bags into long 3cm strips',
          'Link strips together into 3 very long strands',
          'Braid the 3 strands together tightly',
          'Tie handles at each end with extra strips',
          'Test length — should reach armpits when standing on the middle',
        ],
        materials: ['Scissors'],
      ),
  ];

  List<CraftIdea> _plasticCupCrafts(int count) => [
    CraftIdea(
      title: 'Plastic Cup Herb Planter',
      description:
          'Plant herbs in decorated plastic cups for a colourful windowsill garden.',
      steps: [
        'Pierce drainage holes in the bottom',
        'Paint the outside in bright colours or patterns',
        'Write the herb name with a permanent marker',
        'Fill with potting compost',
        'Plant herb seeds and water gently',
      ],
      materials: ['Paint', 'Permanent marker', 'Compost', 'Herb seeds'],
    ),
    CraftIdea(
      title: 'Cup Bubble Wand',
      description:
          'Poke holes in a plastic cup to create a multi-bubble wand that blows dozens of bubbles at once.',
      steps: [
        'Poke 10-15 evenly spaced holes in the base of the cup',
        'Mix washing-up liquid with water and a little sugar for bubble solution',
        'Dip the base of the cup in the solution',
        'Blow gently through the open top',
        'Experiment with hole sizes for different bubble effects',
      ],
      materials: [
        'Washing-up liquid',
        'Water',
        'Sugar',
        'Nail for poking holes',
      ],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Cup Tower Sculpture',
        description:
            'Glue plastic cups together in a geometric tower or pyramid as a desk sculpture.',
        steps: [
          'Paint cups in coordinated colours',
          'Stack cups base-to-base in pairs and glue',
          'Arrange pairs into a tower or pyramid',
          'Glue each layer in place',
          'Top with a small decoration or plant',
        ],
        materials: ['Paint', 'Strong glue', 'Small decoration for top'],
      ),
  ];

  List<CraftIdea> _plasticBottleCrafts(int count) => [
    CraftIdea(
      title: 'Hanging Bottle Garden',
      description:
          'Create a vertical garden from plastic bottles — perfect for herbs, strawberries or flowers.',
      steps: [
        'Cut each bottle in half horizontally',
        'Punch 4 drainage holes in the bottom half',
        'Punch 2 holes near the rim and thread rope through',
        'Fill with potting soil and plant seedlings',
        'Hang on a wall, fence or balcony rail',
      ],
      materials: [
        'Rope or twine',
        'Potting soil',
        'Seeds or seedlings',
        'Scissors',
      ],
    ),
    CraftIdea(
      title: 'Bottle Bird Feeder',
      description:
          'Attract birds to your garden with this simple feeder that takes just 10 minutes to make.',
      steps: [
        'Clean the bottle and let it dry',
        'Cut 2 small oval holes opposite each other near the bottom',
        'Push a wooden stick through both holes as a perch',
        'Cut small feeding holes just above the perch on each side',
        'Fill with bird seed, cap tightly and hang upside down',
      ],
      materials: [
        'Wooden stick or chopstick',
        'String',
        'Bird seed',
        'Craft knife',
      ],
    ),
    CraftIdea(
      title: 'Bottle Piggy Bank',
      description:
          'A fun and colourful money bank from a plastic bottle — great project for all ages.',
      steps: [
        'Clean and dry the bottle completely',
        'Cut a coin slot on the flat side',
        'Paint in your chosen colour',
        'Cut ears from cardboard and glue in place',
        'Add googly eyes and a pipe cleaner tail — use the cap as the snout',
      ],
      materials: [
        'Paint',
        'Cardboard for ears',
        'Glue',
        'Googly eyes',
        'Pipe cleaner',
      ],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Bottle Greenhouse Tunnel',
        description:
            'Cut the bases off multiple bottles and link them into a mini greenhouse tunnel for seedlings.',
        steps: [
          'Cut the base off each bottle',
          'Remove caps for ventilation',
          'Push each bottle base-down into the soil over a row of seedlings',
          'They form a protective tunnel against frost and wind',
          'Remove on warm sunny days',
        ],
        materials: ['Scissors', 'Garden soil', 'Seedlings'],
      ),
    if (count >= 3)
      CraftIdea(
        title: 'Bottle Xylophone',
        description:
            'Fill bottles with different water levels to create a playable musical instrument.',
        steps: [
          'Line up bottles in a row',
          'Fill each with increasing amounts of water',
          'Add food colouring for a rainbow effect',
          'Tap each bottle with a pencil',
          'Adjust water levels to tune your scale',
        ],
        materials: ['Food colouring', 'Pencil or stick', 'Measuring cup'],
      ),
  ];

  List<CraftIdea> _rulerCrafts(int count) => [
    CraftIdea(
      title: 'Ruler Photo Display',
      description:
          'Clip photos along a ruler hung on the wall for a minimalist photo display.',
      steps: [
        'Attach small bulldog clips or pegs along the ruler',
        'Tie string through each end hole to hang',
        'Mount on wall at desired height',
        'Clip your favourite photos onto the pegs',
        'Add fairy lights wound around the ruler for extra glow',
      ],
      materials: [
        'Bulldog clips or pegs',
        'String',
        'Nails or hooks',
        'Fairy lights (optional)',
      ],
    ),
    CraftIdea(
      title: 'Ruler Bookshelf Divider',
      description:
          'Stand rulers upright as bookends or dividers to organise books and files on a shelf.',
      steps: [
        'Paint or decorate each ruler differently',
        'Drill a small hole in one end of each ruler',
        'Thread wire through and loop around a small wooden block as a base',
        'Stand between books as a decorative divider',
        'Label each section',
      ],
      materials: ['Paint', 'Small wooden blocks', 'Drill', 'Wire'],
    ),
    if (count >= 2)
      CraftIdea(
        title: 'Ruler Picture Frame',
        description:
            'Build a picture frame from four rulers joined at the corners — a unique stationery-themed frame.',
        steps: [
          'Cut or arrange 4 rulers to form a rectangle',
          'Join corners with strong glue or small corner brackets',
          'Let glue dry fully',
          'Attach picture hanging hardware to the back',
          'Slide your photo in behind the rulers',
        ],
        materials: [
          'Strong glue or corner brackets',
          'Picture hanging hardware',
          'Sandpaper for rough edges',
        ],
      ),
  ];

  List<CraftIdea> _sharpenerCrafts(int count) => [
    CraftIdea(
      title: 'Sharpener Stamp Art',
      description:
          'Use the flat base of a sharpener dipped in paint as a unique square/rectangular stamp.',
      steps: [
        'Clean the base of the sharpener',
        'Press onto an ink pad or paint-covered plate',
        'Stamp in patterns on paper, fabric or cards',
        'Create repeating geometric patterns',
        'Try different colours and overlapping patterns',
      ],
      materials: ['Ink pad or paint', 'Paper or fabric', 'Plate for paint'],
    ),
    CraftIdea(
      title: 'Sharpener Mosaic',
      description:
          'Collect multiple sharpeners and glue them in a pattern onto a box or frame as a quirky mosaic.',
      steps: [
        'Collect sharpeners in different shapes and colours',
        'Arrange them in a pattern on your chosen surface',
        'Glue each in place with strong adhesive',
        'Fill gaps with paint if desired',
        'Seal with clear varnish',
      ],
      materials: [
        'Strong adhesive',
        'Box or picture frame',
        'Paint',
        'Varnish',
      ],
    ),
    CraftIdea(
      title: 'Sharpener Pencil Shaving Art',
      description:
          'Use the pencil shavings produced by sharpening to create delicate spiral artwork.',
      steps: [
        'Sharpen multiple pencils over paper to collect shavings',
        'Arrange shavings in spiral or flower patterns on card',
        'Carefully apply PVA glue to hold them in place',
        'Let dry without disturbing',
        'Frame the delicate artwork under glass',
      ],
      materials: ['PVA glue', 'Card', 'Frame with glass', 'Tweezers'],
    ),
  ];

  // ── Generic fallback ──────────────────────────────────────────────────────

  List<CraftIdea> _genericCrafts(List<String> objects) => [
    CraftIdea(
      title: 'Upcycled Mosaic Art',
      description:
          'Combine your recycled items to create a colourful mosaic wall art piece — every combination is unique!',
      steps: [
        'Clean all items',
        'Sketch your design on a thick cardboard base',
        'Break or cut materials into small pieces',
        'Arrange on base and glue down',
        'Seal with varnish when fully dry',
      ],
      materials: ['Cardboard base', 'Strong adhesive', 'Varnish', 'Paint'],
    ),
    CraftIdea(
      title: 'Mixed Recycled Sculpture',
      description:
          'Build a 3D sculpture combining all your recycled objects — no rules, just creativity!',
      steps: [
        'Lay out all objects and sketch a sculpture idea',
        'Build a base structure from the largest items',
        'Add smaller pieces using glue or wire',
        'Paint or leave natural',
        'Add a title label and display it!',
      ],
      materials: ['Strong glue or hot glue gun', 'Wire', 'Paint', 'Label card'],
    ),
    CraftIdea(
      title: 'Eco Gift Wrapping Set',
      description:
          'Use your recycled materials creatively as unique, zero-waste gift wrapping.',
      steps: [
        'Flatten and cut materials into sheets',
        'Wrap gifts and tie with natural string',
        'Create bows from strips of the same material',
        'Write gift tags on cardboard scraps',
        'Decorate with hand-drawn patterns',
      ],
      materials: ['Scissors', 'Natural string', 'Markers'],
    ),
    CraftIdea(
      title: 'Recycled Mobile Hanging',
      description:
          'Hang various recycled items from a stick at different heights to make a decorative mobile.',
      steps: [
        'Collect items of different shapes and weights',
        'Tie string to each item at different lengths',
        'Tie all strings to a horizontal stick',
        'Balance by adjusting string positions',
        'Hang from ceiling or window frame',
      ],
      materials: ['String', 'Wooden stick or ruler', 'Scissors'],
    ),
    CraftIdea(
      title: 'Recycled Time Capsule Box',
      description:
          'Pack your recycled objects into a decorated box and bury it as a time capsule for the future.',
      steps: [
        'Find or build a sturdy box',
        'Decorate the outside with recycled materials',
        'Write a letter about today to put inside',
        'Pack cleaned recycled items that represent your life now',
        'Seal and store — open in 5 or 10 years!',
      ],
      materials: ['Sturdy box', 'Glue', 'Paint', 'Paper and pen for letter'],
    ),
  ];
}
