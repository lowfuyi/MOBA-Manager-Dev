# Alpha tester feedback form

Status: script written and logic-checked against stubbed Google APIs. It has not been run in a real Google account yet (it cannot be run from the build computer).

## Set up (about 1 minute, once)

1. Open https://script.google.com and press **New project**.
2. Delete the sample code, paste all of `tools/feedback_form.gs`, press **Save**.
3. Pick `createAlphaFeedbackForm` in the toolbar and press **Run**.
4. Google asks for permission (Forms, Sheets, Drive). The screen may say the app is unverified, because it is your own script: press **Advanced**, then **Go to project**, then **Allow**.
5. Open **Execution log**. It prints three links: the form to send to testers, the form editor, and the responses sheet.
6. In the form editor, open the **Responses** tab and check that responses are being accepted. Send the first link together with the APK.

Anything can be edited afterwards in the Google Forms editor. Re-running the script makes a second, separate form.

## How responses are reviewed

Answers land in the responses sheet in your Drive. Tell Claude "review the Alpha feedback" and Claude reads the sheet through the Google Drive connector, then reports: counts and averages per question, the free-text answers grouped into themes, bugs ranked by how many testers hit them, and a proposed fix list that feeds the next Alpha build. Nothing is sent anywhere else.

Testers do not need a Google account if the form is left on "Anyone with the link" (the default).

## Questions and why they are asked

| Section | Question | What it tells us |
|---|---|---|
| 1 About you | Phone model and Android version | Which devices see which problems (checklist item 5.1) |
| 1 | Sports-manager and MOBA experience | Whether confusion comes from the genre or from our screens |
| 1 | Pasted "Copy feedback note" | Version, club, season, pace log, start-up time, memory, comfort options, with no typing |
| 2 Played | Total time and how far they got | Whether people reach the season loop at all (retention signal) |
| 3 Clear | First 5 minutes understood (1-5) | Onboarding quality (checklist 4.1, 4.4) |
| 3 | Grid: draft, Game Plan, Team Bonds, training, contracts, finance, standings and Form Rating, watching, report, practice | Which feature is confusing or unused, so we fix or explain the right one |
| 3 | Stuck or confused; word, number or icon not understood | Direct list of tooltips and copy to fix |
| 4 Pace | Game length, 75 s watch window, skipping | Tests the founder's 5-minute target and the fixed watch time (checklist 4.2) |
| 4 | Exciting, fair (1-5); repetitive or tiring, and after how many matches | Tests for game tiredness, the founder's open worry |
| 5 Balance | Choices mattered (1-5); difficulty; money; unbeatable or useless things | Real-play check on calibration, and on the title and cash concentration seen in simulation |
| 6 Look | Looks, readability, tap ease (1-5); comfort options used | Arena Dusk reaction and accessibility, in the founder's top priority (ease of use) |
| 7 Problems | Crash or freeze; save kept; slow or warm; what was wrong and what they did before | Bug reports with a way to reproduce them (checklist 5.1) |
| 8 Overall | Recommend 0-10; keep playing next week (1-5) | Headline Alpha-exit number and retention intent |
| 8 | One thing to change first (required); liked most; next features (pick up to 3) | Priority order for the next build |
| 8 | Follow-up consent and contact | Lets us ask a tester one more question |

Required questions are kept to the ones needed for the numbers above. Every other question can be skipped.

## Alpha exit use

The beta decision numbers in `ALPHA-EXIT-CHECKLIST.md` that depend on real players (clarity, pace, crashes, would-recommend) are read from this sheet. The checklist's thresholds are unchanged; this form is the evidence source for them.
