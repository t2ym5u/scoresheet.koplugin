-- rules.lua — how each sheet scores, in English and French ({ en, fr }).

local R = {}

R.home = {
[[
Score sheets — keep the score of the card and board games you play around a real table.

• Pick a sheet: Tarot, Belote / Coinche, Word tile game, Rummy, or the free sheet for any other game.
• Each sheet keeps its own game in progress: close the screen, come back later, it is still there.
• Tap a name at the top of a sheet to rename it. Names are remembered for the next games.
• Tap a round line to see its details. Undo removes the last round.
• New game (☰ menu) keeps the names and clears the scores.
• The leader's total is shown inverted (white on black).

Each sheet's own rules are under ☰ → Rules once it is open.
]],
[[
Feuilles de score — tenez les comptes des jeux de cartes et de société auxquels vous jouez autour d'une vraie table.

• Choisissez une feuille : Tarot, Belote / Coinche, Jeu de lettres, Rami, ou la feuille libre pour tout autre jeu.
• Chaque feuille garde sa partie en cours : fermez l'écran, revenez plus tard, elle est toujours là.
• Touchez un nom en haut de la feuille pour le changer. Les noms sont retenus pour les parties suivantes.
• Touchez une ligne pour voir le détail de la manche. Annuler retire la dernière manche.
• Nouvelle partie (menu ☰) garde les noms et remet les scores à zéro.
• Le total du meneur s'affiche en inversé (blanc sur noir).

Les règles de chaque feuille sont dans ☰ → Règles une fois la feuille ouverte.
]],
}

R.tarot = {
[[
Tarot — French rules (Fédération Française de Tarot), 3, 4 or 5 players.

For each deal enter the taker, the contract, the number of oudlers (the 21, the 1 and the Excuse) in the taker's tricks, and the card points the taker's side made (out of 91).

Points needed: 56 with no oudler, 51 with 1, 41 with 2, 36 with 3. A half point goes to the side that wins the deal (40½ with 41 needed counts 40, 41½ counts 42).

Value of the deal = (25 + points over or under) × contract
• Petite ×1, Garde ×2, Garde sans ×4, Garde contre ×6.
• Petit au bout: 10 × contract to the side that took the 1 in the last trick, whatever the result.
• Poignée (simple 20, double 30, triple 40, not multiplied): always to the side that wins the deal, whoever showed it; each side may show one. Trumps needed: 13/15/18 with 3 players, 10/13/15 with 4, 8/10/13 with 5.
• Chelem: announced and made +400, made without announcing +200, announced and failed −200, made by the defence: +200 to each defender.

Each defender pays (or receives) the value of the deal. With 4 players the taker scores 3 times it, with 3 players twice. With 5 players the taker calls a king: the taker scores twice and the called partner once; a taker who called himself (or whose king was in the dog) plays alone and scores 4 times. The scores always add up to zero.

Example (FFT): Garde, 2 oudlers, 49 points, poignée and petit au bout for the taker: (25 + 8) × 2 + 20 + 20 = 106. Each defender −106, the taker +318.
]],
[[
Tarot — règles de la Fédération Française de Tarot, à 3, 4 ou 5 joueurs.

Pour chaque donne, indiquez le preneur, le contrat, le nombre de bouts (le 21, le petit et l'excuse) dans les plis du preneur, et les points réalisés par le camp du preneur (sur 91).

Points à faire : 56 sans bout, 51 avec 1, 41 avec 2, 36 avec 3. Un demi-point va au camp qui gagne la donne (40½ pour 41 à faire compte 40, 41½ compte 42).

Valeur de la donne = (25 + points de gain ou de perte) × contrat
• Petite ×1, Garde ×2, Garde sans ×4, Garde contre ×6.
• Petit au bout : 10 × contrat au camp qui a pris le petit au dernier pli, quel que soit le résultat.
• Poignée (simple 20, double 30, triple 40, non multipliée) : toujours au camp qui gagne la donne, quel que soit celui qui l'a montrée ; chaque camp peut en montrer une. Atouts : 13/15/18 à 3 joueurs, 10/13/15 à 4, 8/10/13 à 5.
• Chelem : annoncé et réalisé +400, réalisé sans annonce +200, annoncé et chuté −200, réalisé par la défense : +200 à chaque défenseur.

Chaque défenseur paie (ou reçoit) la valeur de la donne. À 4 joueurs le preneur marque 3 fois cette valeur, à 3 joueurs 2 fois. À 5 joueurs le preneur appelle un roi : il marque 2 fois et son partenaire 1 fois ; un preneur qui s'est appelé lui-même (ou dont le roi est au chien) joue seul et marque 4 fois. La somme des scores est toujours nulle.

Exemple (FFT) : Garde, 2 bouts, 49 points, poignée et petit au bout pour le preneur : (25 + 8) × 2 + 20 + 20 = 106. Chaque défenseur −106, le preneur +318.
]],
}

R.belote = {
[[
Belote / Coinche — two teams, common French rules. Choose the variant and the target score (1000, 1500, 2000 or your own) in the ☰ menu. The first team to reach the target at the end of a hand wins (the highest total if both do).

For each hand enter the team that took, the card points it made (out of 162, last trick's 10 included — the other team gets the rest), who held belote-rebelote, and a capot if a team won every trick.

Belote
• The taking team must make more points than the other one (belote-rebelote counts for its holder). Then each team scores what it made.
• Otherwise it is « dedans »: the other team scores 162, the takers nothing.
• Tie (81–81, « litige »): the defence scores its 81, the takers' 81 wait and go to whichever team wins the next hand.
• Capot: 252 instead of 162.
• Belote-rebelote: +20, always kept by the team that holds it.

Coinche (« points faits + contrat »)
• Enter the bid (80 to 160, or capot) and whether it was coinched (×2) or surcoinched (×4).
• The takers must reach their bid (belote-rebelote counts towards it) and make at least 82; a capot bid needs every trick.
• Made: the takers score bid + points made, the defence its points. Made and coinched: the takers score bid × 2 (or × 4) + 160, the defence nothing.
• Failed: the defence scores 160 + bid (× 2 or × 4 if coinched), the takers nothing.
• Capot: 250 card points. Belote-rebelote: +20, always kept by its holder.
• No rounding: points are scored as made.
]],
[[
Belote / Coinche — deux équipes, règles françaises courantes. Choisissez la variante et le score à atteindre (1000, 1500, 2000 ou le vôtre) dans le menu ☰. La première équipe à atteindre ce score à la fin d'une donne gagne (le plus haut total si les deux l'atteignent).

Pour chaque donne, indiquez l'équipe qui a pris, les points qu'elle a faits (sur 162, dix de der compris — l'autre équipe a le reste), qui avait belote-rebelote, et un capot si une équipe a fait tous les plis.

Belote
• L'équipe preneuse doit faire plus de points que l'autre (belote-rebelote compte pour celle qui l'a). Chaque équipe marque alors ce qu'elle a fait.
• Sinon elle est « dedans » : l'autre équipe marque 162, les preneurs rien.
• Égalité (81–81, « litige ») : la défense marque ses 81, les 81 des preneurs sont mis de côté et vont à l'équipe qui gagne la donne suivante.
• Capot : 252 au lieu de 162.
• Belote-rebelote : +20, toujours acquis à l'équipe qui l'a.

Coinche (« points faits + contrat »)
• Indiquez le contrat (80 à 160, ou capot) et s'il a été coinché (×2) ou surcoinché (×4).
• Les preneurs doivent atteindre leur contrat (belote-rebelote compte) et faire au moins 82 ; un contrat capot exige tous les plis.
• Réussi : les preneurs marquent contrat + points faits, la défense ses points. Réussi et coinché : les preneurs marquent contrat × 2 (ou × 4) + 160, la défense rien.
• Chuté : la défense marque 160 + contrat (× 2 ou × 4 si coinché), les preneurs rien.
• Capot : 250 points. Belote-rebelote : +20, toujours acquis à l'équipe qui l'a.
• Pas d'arrondi : les points sont marqués tels quels.
]],
}

R.words = {
[[
Word tile game — 2 to 4 players.

• On your turn, type the score of the word(s) you placed, as counted on the board. Tick « +50 » when you placed all seven tiles at once. Pass scores 0.
• Turns go round the table in order; tap another name to change whose turn it is.
• End of game (button on the sheet): type the value of the tiles left on each rack. Everyone loses the value of their own tiles; a player who used all their tiles gains the total of the others'.
• Highest total wins.
]],
[[
Jeu de lettres — 2 à 4 joueurs.

• À votre tour, tapez le score du ou des mots posés, compté sur le plateau. Cochez « +50 » si vous avez posé vos sept lettres d'un coup. Passer vaut 0.
• Les tours suivent l'ordre de la table ; touchez un autre nom pour changer de joueur.
• Fin de partie (bouton de la feuille) : tapez la valeur des lettres restées sur chaque chevalet. Chacun perd la valeur de ses lettres ; un joueur qui n'en a plus gagne le total de celles des autres.
• Le plus haut total gagne.
]],
}

R.rummy = {
[[
Rummy — 2 to 8 players, penalty points.

• At the end of each round, type the penalty points of the cards left in each player's hand. The player who went out scores 0.
• A player whose total goes over the limit (100 by default, change it in the ☰ menu) is out of the game; the sheet skips them from then on.
• The last player still in wins. The lowest total leads.
]],
[[
Rami — 2 à 8 joueurs, points de pénalité.

• À la fin de chaque manche, tapez les points des cartes restées en main de chaque joueur. Celui qui a fini marque 0.
• Un joueur dont le total dépasse la limite (100 par défaut, modifiable dans le menu ☰) est éliminé ; la feuille ne lui demande plus rien.
• Le dernier joueur en jeu gagne. Le plus petit total mène.
]],
}

R.free = {
[[
Free sheet — any game, 1 to 8 players.

• Each round, type the points of every player (± for a negative score; blank counts 0).
• In the ☰ menu: who wins (highest or lowest total) and an optional target score — the game ends as soon as a total reaches it.
]],
[[
Feuille libre — n'importe quel jeu, de 1 à 8 joueurs.

• À chaque manche, tapez les points de chaque joueur (± pour un score négatif ; vide compte 0).
• Dans le menu ☰ : qui gagne (le plus haut ou le plus petit total) et un score à atteindre facultatif — la partie s'arrête dès qu'un total l'atteint.
]],
}

return R
