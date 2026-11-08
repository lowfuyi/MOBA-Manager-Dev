/**
 * Alpha tester feedback form builder (Google Apps Script).
 *
 * How to use (about 1 minute):
 *  1. Go to https://script.google.com and press "New project".
 *  2. Delete the sample code, paste this whole file, press Save.
 *  3. Choose the function "createAlphaFeedbackForm" in the toolbar and press Run.
 *  4. Google asks you to allow access (Forms, Sheets, Drive). Review and allow.
 *  5. Open "Execution log": it prints the link to SEND to testers, the link to EDIT
 *     the form, and the link to the RESPONSES sheet.
 *
 * It creates one new Form and one new Sheet in your own Google Drive. It does not touch
 * any existing file. Answers go to the Sheet; testers do not need a Google account
 * if the form is set to "Anyone with the link" (this is the default for a new form).
 *
 * Question guide and why each question is asked: docs/ALPHA-FEEDBACK-FORM.md
 */

var FORM_TITLE = 'MOBA Esports Manager: Alpha tester feedback';
var SHEET_TITLE = 'MOBA Esports Manager: Alpha feedback responses';

var FEATURES = [
  'Picking the draft',
  'Game Plan (before a match)',
  'Team Bonds / chemistry screen',
  'Training and rest',
  'Contracts and free agents',
  'Finance screen',
  'Standings, trophies and Form Rating',
  'Watching a match',
  'Match report',
  'Practice matches (Quick Match / Exhibition)'
];
var FEATURE_COLUMNS = ["Didn't try it", 'Confusing', 'Okay', 'Clear'];

function createAlphaFeedbackForm() {
  var form = FormApp.create(FORM_TITLE);
  form.setDescription(
    'Thank you for testing the Alpha. This takes about 6 to 8 minutes. ' +
    'There are no right or wrong answers, and being honest about what annoyed or confused you helps most. ' +
    'Skip any question you cannot answer. Your answers go only to the game developer.');
  form.setCollectEmail(false);
  form.setLimitOneResponsePerUser(false);
  form.setProgressBar(true);
  form.setShowLinkToRespondAgain(false);
  form.setConfirmationMessage('Thank you! Your feedback goes straight into the next Alpha update.');

  // ---- 1. About you and your phone ----
  section_(form, '1. About you and your phone', 'So we can tell which phones and player types see which problems.');
  text_(form, 'Name or nickname (optional)', false);
  text_(form, 'Phone model and Android version (for example: Samsung A54, Android 14)', true);
  choice_(form, 'How much do you play sports or esports manager games?',
    ['Never played one', 'A little', 'Regularly', 'A lot, it is a favourite genre'], true);
  choice_(form, 'How much do you play MOBA games (League of Legends, Mobile Legends, Dota 2, Honor of Kings and similar)?',
    ["I don't play MOBAs", 'Casually', 'Regularly', 'Competitively'], true);
  paragraph_(form, 'Game info: in the game open Settings, tap "Copy feedback note", then paste it here (optional, but it helps a lot)', false);

  // ---- 2. How much you played ----
  section_(form, '2. How much you played', null);
  choice_(form, 'How long did you play in total?',
    ['Less than 15 minutes', '15 to 30 minutes', '30 to 60 minutes', '1 to 2 hours', 'More than 2 hours'], true);
  choice_(form, 'How far did you get?',
    ['Did not finish my first match day', 'Played several match days', 'Finished a league season', 'Finished more than one season'], true);

  // ---- 3. Was it clear? ----
  section_(form, '3. Was it clear?', 'Tell us how each part felt to you.');
  scale_(form, 'In my first 5 minutes I understood what to do next', 1, 5, 'Totally lost', 'Always knew', true);
  var grid = form.addGridItem();
  grid.setTitle('How did each part feel?');
  grid.setHelpText('Pick one for each row. Skip a row if you did not see it.');
  grid.setRows(FEATURES);
  grid.setColumns(FEATURE_COLUMNS);
  grid.setRequired(false);
  paragraph_(form, 'Where did you get stuck, or what confused you most?', false);
  paragraph_(form, 'Was there a number, word or icon you did not understand?', false);

  // ---- 4. Matches and pace ----
  section_(form, '4. Matches and pace', 'We aim for about 5 minutes per game including the draft.');
  choice_(form, 'How long did one game feel, from draft to result?',
    ['Too short', 'About right', 'A bit long', 'Too long'], true);
  choice_(form, 'The 75-second match watching time felt',
    ['Too short', 'About right', 'Too long'], true);
  choice_(form, 'Did you skip or fast-forward the match?',
    ['Never', 'Sometimes', 'Most of the time'], true);
  scale_(form, 'Matches felt exciting', 1, 5, 'Boring', 'Exciting', true);
  scale_(form, 'Results felt fair and believable', 1, 5, 'Unfair', 'Fair', true);
  choice_(form, 'Did the game ever feel repetitive or tiring?',
    ['No', 'A little', 'Yes'], true);
  text_(form, 'If it felt repetitive or tiring, after about how many matches?', false);

  // ---- 5. Choices and balance ----
  section_(form, '5. Choices and balance', null);
  scale_(form, 'My choices (draft, game plan, training) changed the results', 1, 5, 'Not at all', 'Clearly', true);
  choice_(form, 'The difficulty was',
    ['Too easy', 'About right', 'Too hard'], true);
  choice_(form, 'Money in my club was',
    ['A struggle', 'Balanced', 'Plenty spare'], false);
  paragraph_(form, 'Did any club, hero, strategy or trick feel unbeatable or useless? Tell us which.', false);

  // ---- 6. Look and feel ----
  section_(form, '6. Look and feel', null);
  scale_(form, 'I like how the game looks', 1, 5, 'Not at all', 'A lot', true);
  scale_(form, 'Text was easy to read', 1, 5, 'Hard', 'Easy', true);
  scale_(form, 'Buttons were easy to tap and I rarely missed', 1, 5, 'Frustrating', 'Easy', true);
  var comfort = form.addCheckboxItem();
  comfort.setTitle('Which comfort options did you try?');
  comfort.setChoiceValues(['Large text', 'Colour-blind palette', 'Reduced animation', 'None of them']);
  comfort.setRequired(false);
  paragraph_(form, 'Anything in the look that felt ugly, cramped or hard to use?', false);

  // ---- 7. Problems ----
  section_(form, '7. Problems', 'Bugs are the most useful thing you can report.');
  choice_(form, 'Did the game crash or freeze?',
    ['No', 'Once', 'A few times', 'Often'], true);
  choice_(form, 'Did your game keep its progress after you closed and reopened it?',
    ["I didn't test this", 'Yes', 'No'], true);
  choice_(form, 'Did the game feel slow, or did your phone get warm?',
    ['No', 'A little', 'Yes'], true);
  paragraph_(form, 'Did you see anything wrong (wrong numbers, stuck screen, cut-off text)? What were you doing just before?', false);

  // ---- 8. Overall ----
  section_(form, '8. Overall', null);
  scale_(form, 'How likely are you to recommend this game to a friend who likes esports?', 0, 10, 'Not likely', 'Very likely', true);
  scale_(form, 'If this game were on your phone, how likely are you to keep playing next week?', 1, 5, 'Not likely', 'Very likely', true);
  paragraph_(form, 'What did you like most?', false);
  paragraph_(form, 'If we could fix or change only ONE thing first, what should it be?', true);
  var wants = form.addCheckboxItem();
  wants.setTitle('Which would you most like to see next? (pick up to 3)');
  wants.setChoiceValues([
    'Play against friends online',
    'More leagues and regions',
    'Deeper player development and training',
    'Story moments and random events',
    'Richer match watching',
    'More ways to customise my team',
    'Better explanations and tutorials'
  ]);
  wants.showOtherOption(true);
  wants.setValidation(FormApp.createCheckboxValidation().requireSelectAtMost(3).setHelpText('Pick up to 3.').build());
  wants.setRequired(false);
  choice_(form, 'May we contact you with follow-up questions?', ['No', 'Yes'], false);
  text_(form, 'If yes, how should we reach you (email or WhatsApp)?', false);

  // ---- Responses go to a new sheet ----
  var ss = SpreadsheetApp.create(SHEET_TITLE);
  form.setDestination(FormApp.DestinationType.SPREADSHEET, ss.getId());

  Logger.log('SEND THIS LINK TO TESTERS : ' + form.getPublishedUrl());
  Logger.log('Edit the form             : ' + form.getEditUrl());
  Logger.log('Responses sheet           : ' + ss.getUrl());
  Logger.log('Questions created         : ' + form.getItems().length);
}

// ---- helpers ----
function section_(form, title, help) {
  var s = form.addPageBreakItem();
  s.setTitle(title);
  if (help) { s.setHelpText(help); }
}

function text_(form, title, required) {
  var q = form.addTextItem();
  q.setTitle(title);
  q.setRequired(required);
}

function paragraph_(form, title, required) {
  var q = form.addParagraphTextItem();
  q.setTitle(title);
  q.setRequired(required);
}

function choice_(form, title, choices, required) {
  var q = form.addMultipleChoiceItem();
  q.setTitle(title);
  q.setChoiceValues(choices);
  q.setRequired(required);
}

function scale_(form, title, low, high, lowLabel, highLabel, required) {
  var q = form.addScaleItem();
  q.setTitle(title);
  q.setBounds(low, high);
  q.setLabels(lowLabel, highLabel);
  q.setRequired(required);
}
