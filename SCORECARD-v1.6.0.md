# CricXii v1.6.0+23 scorecard design

This release standardizes CricXii match presentation around a familiar cricket scorecard hierarchy.

## Team Match

1. Innings header: team/innings label on the left, score and overs on the right.
2. Batting: Batter, dismissal detail, R, B, 4s, 6s and SR.
3. Summary rows: Extras with b/lb/w/nb/p split, Total with overs and run rate, and Yet to Bat.
4. Bowling: Bowler, O, M, R, W, NB, WD and ECO.
5. Fall of Wickets: player, cumulative score and over.
6. Partnerships: pair contribution plus partnership runs/balls.
7. Super Overs use exactly the same scorecard block and can repeat/paginate.

## Singles

Singles is not a two-team innings, so CricXii does not invent a fake team total. The match result shows a scorecard of each batting turn and recorded bowling figures, then keeps the official CricXii ranking as a separate section. In Direct Runs mode, B/4s/6s/SR are shown as `-` because those details were not recorded.

## Consistency

The same domain scorecard builders feed result screens, standalone PDFs and Today Performance full-match sections so dismissal text, extras and figures do not drift between surfaces.
