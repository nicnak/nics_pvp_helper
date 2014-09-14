script "nics_pvp_tracker.ash";
notify nicnak;

string viewPattern = "a href\=\"(peevpee\.php\\?action\=log.*?lid\=(\\d+).*?)\".*?m</small></td><td><small>(.*?)</small>";
string playersPattern = "<a href=\"showplayer.php\\?who=\\d+\"><b>(.*?)</b></a> calls out <a href=\"showplayer.php\\?who=\\d+\"><b>(.*?)</b></a> for battle!";		
string contestPattern = "<tr[a-zA-Z0-9/=\":. ]*?>\s*?<td[a-zA-Z0-9/=\":. ]*?>\s*?(<img[a-zA-Z0-9/=\":. _]*?>)?\s*?</td>.*?<center>\s*?Round \\d+: <b[a-zA-Z0-9/=\":. ]*?>(.*?)</b>\s*?<div[a-zA-Z0-9/=\":. ]*?>.*?</div>\s*?</center>\s*?<p>(.*?)</td>\s*?<td[a-zA-Z0-9/=\":. ]*?>\s*?(<img[a-zA-Z0-9/=\":. _]*?>)?\s*?</td>\s*?</tr>";
string marginPattern = ".*?(\\d+%*).*?";
string this_player = to_lower_case(my_name());
string greeting = "<p>Welcome to <a href=\"showplayer.php\?who=1655960\">NicNak</a>'s PVP tracker. Credit to <a href=\"showplayer.php\?who=2205257\">Vhaeraun<a> for his great bookkeeper script which I snagged some bits of code from.";
string file_name_base = this_player + "_nics_pvp_tracker_v1_";

record WltStat {
  int count;  // win + loss + tie
  int win;
  int tie;
  int loss;
};
record MiniStat {
  WltStat offense;
  WltStat defense;
};
record PlayerStat {
  MiniStat overall;  // Sum of minis array, ignoring ties.
  MiniStat [string] minis;
};
PlayerStat player_stat;

record StoredRound{
  // For this mini, is it a win, loss or tie.
  string mini;
  boolean win;
  boolean loss;
  boolean tie;
};
record StoredFight{
  string attacker;
  string defender;
  boolean attacking;  // true if attacker == this_player
  boolean won;  // true if this_player won
  StoredRound [string] rounds;
};

boolean isCompact() {
  string currentSettings = visit_url("account.php?tab=interface");
  string compactedPattern = "<input[ a-zA-Z=\"0-9]*checked=\"checked\"[ a-zA-Z0-9=\"]*name=\"flag_compactfights\"[ a-zA-Z=\"0-9]*/>";
  matcher compactMatcher = create_matcher(compactedPattern,currentSettings);
  return compactMatcher.find();
}

void verifySettings() {
  if (isCompact()) {
    abort("Compact pvp mode not currently supported, please disable via account options");
  }
}

string getCurrentSeason() {
  string page = visit_url("peevpee.php?place=rules");
  matcher m = create_matcher("<b>Current Season: </b>(\\d+)", page);
  m.find();
  return group(m, 1);
}

string TD(string s){
  return "<td>" + s + "</td>";
}
string TR(string s){
  return "<tr>" + s + "</tr>";
}

string formatMiniStat(MiniStat mStat, string mini, string[string] fields) {
  int totalFights = mStat.offense.count + mStat.defense.count;
  string row = "";
  if (totalFights > 0) {
    int totalWins = mStat.offense.win + mStat.defense.win + mStat.defense.tie;
    int totalLoss = mStat.offense.loss + mStat.defense.loss + mStat.offense.tie;
    int totalPercent = truncate(to_float(totalWins)/totalFights*100);

    row += TD(mini);

    if (fields contains "TOTAL") {
      row += TD(totalFights);
      row += TD(totalWins + ":" + totalLoss);
      row += TD(totalPercent + "%");
    }

    if (fields contains "OFFENSE") {
      row += TD(mStat.offense.count);
      if (mStat.offense.count > 0) {
	int percent = truncate(to_float(mStat.offense.win) / mStat.offense.count * 100);
	row += TD(mStat.offense.win + ":" + mStat.offense.loss + "(" + mStat.offense.tie + ")");
	row += TD(percent + "%");
      } else {
	row += TD("") + TD("");
      }
    }

    if (fields contains "DEFENSE") {
      row += TD(mStat.defense.count);
      if (mStat.defense.count > 0) {
	int percent = truncate(to_float(mStat.defense.win + mStat.defense.tie) / mStat.defense.count * 100);
	row += TD(mStat.defense.win + "(" + mStat.defense.tie + "):" + mStat.defense.loss);
	row += TD(percent + "%");
      } else {
	row += TD("") + TD("");
      }
    }
  }
  return row;
}

string formatResults(string[string] fields){
  string html = "<p>";
  html += "<table border='1' cellspacing='4'><thead>";
  string row1 = "<th rowspan='2'>Mini</th>";
  string row2 = "";
  if (fields contains "TOTAL") {
    row1 += "<th colspan='3'>Total</th>";
    row2 += "<th>Count</th><th>W:L</th><th>%</th>";
  }
  if (fields contains "OFFENSE") {
    row1 += "<th colspan='3'>Offense</th>";
    row2 += "<th>Count</th><th>W:L(T)</th><th>%</th>";
  }
  if (fields contains "DEFENSE") {
    row1 += "<th colspan='3'>Defense</th>";
    row2 += "<th>Count</th><th>W(T):L</th><th>%</th>";
  }
  html += TR(row1) + TR(row2) + "</thead><tbody>";

  foreach mini in player_stat.minis{
    MiniStat mStat = player_stat.minis[mini];
    string row = formatMiniStat(mStat, mini, fields);
    if (row != "") {
      html += TR(row);
    }
  }
  html += "</body><tfoot>";
  html += TR(formatMiniStat(player_stat.overall, "Total Fights", fields));
  html += "</tfoot></table>";
  return html;
}

void incrementWltStat(WltStat s, StoredRound thisRound) {
  if (thisRound.win) {
    s.win = s.win + 1;
  }
  if (thisRound.loss) {
    s.loss = s.loss + 1;
  }
  if (thisRound.tie) {
    s.tie = s.tie + 1;
  }
  s.count = s.count + 1;
}

StoredFight processFight(string url) {
  StoredFight thisFight;
  string rawFight = visit_url(url);
  matcher playerMatcher = create_matcher(playersPattern, rawFight);
  playerMatcher.find();
  thisFight.attacker = to_lower_case(group(playerMatcher, 1));
  thisFight.defender = to_lower_case(group(playerMatcher, 2));
  print("Processing " + thisFight.attacker + " vs " + thisFight.defender);
	
  if(thisFight.attacker == this_player){
    thisFight.attacking = true;
  }

  matcher roundMatcher = create_matcher(contestPattern, rawFight);
  int attack_wins = 0;
  int defend_wins = 0;
  while(roundMatcher.find()){
    string attacker_star = group(roundMatcher, 1);
    string title = group(roundMatcher, 2);
    string round_detail = group(roundMatcher, 3);
    string defender_star = group(roundMatcher, 4);

    StoredRound thisRound;
    if (attacker_star != "") {
      attack_wins += 1;
      thisRound.win = thisFight.attacking;
      thisRound.loss = !thisFight.attacking;
    } else if (defender_star != "") {
      defend_wins += 1;
      thisRound.win = !thisFight.attacking;
      thisRound.loss = thisFight.attacking;
    } else {
      // Its a TIE
      thisRound.tie = true;
    }

    thisRound.mini = title;
    thisFight.rounds[title] = thisRound;
  }

  if (attack_wins > defend_wins && thisFight.attacking) {
    thisFight.won = true;
  }
  if (defend_wins >= attack_wins && !thisFight.attacking) {
    thisFight.won = true;
  }

  return thisFight;
}

void evaluateStoredFight(StoredFight thisFight) {
  // For each of the rounds, gather per-mini stats
  foreach key in thisFight.rounds {
    StoredRound thisRound = thisFight.rounds[key];
    MiniStat mStat = player_stat.minis[thisRound.mini];
    if(thisFight.attacking) {
      incrementWltStat(mStat.offense, thisRound);
    } else {
      incrementWltStat(mStat.defense, thisRound);
    }
    player_stat.minis[thisRound.mini] = mStat;
  }

  // For the entire fight, create a temp round that matches the fight outcome and then gather stats.
  StoredRound tempFight;
  tempFight.win = thisFight.won;
  tempFight.loss = !thisFight.won;
  if(thisFight.attacking){
    incrementWltStat(player_stat.overall.offense, tempFight);
  } else {
    incrementWltStat(player_stat.overall.defense, tempFight);
  }
}

string process(string[string] fields) {
  verifySettings();
  int maxFights = to_int(fields["MAX_FIGHTS"]);

  string fileName = file_name_base + getCurrentSeason() + ".txt";
  StoredFight [string] storedFights;
  file_to_map(fileName, storedFights);

  string archive = visit_url("peevpee.php?place=logs&mevs=0&oldseason=0&showmore=1");

  matcher logMatcher = create_matcher(viewPattern, archive); 
  int i=0;
  while (logMatcher.find() && i < maxFights) {
    i += 1;
    string oneFight = group(logMatcher,1);
    string fightId = group(logMatcher,2);
    string fightResults = group(logMatcher,3);

    if(!(storedFights contains fightId)){
      storedFights[fightId] = processFight(oneFight);
    }
    evaluateStoredFight(storedFights[fightId]);
  }
  map_to_file(storedFights, fileName);

  string page;
  page += greeting;
  page += "<p>PvP Stats for " + i + " fights";
  page += formatResults(fields);
  return page;
}

string[string] readPrefs() {
  string fileName = file_name_base + "prefs.txt";
  string[string] fields;
  file_to_map(fileName, fields);
  if (!(fields contains "MAX_FIGHTS")) {
    // defaults
    fields["MAX_FIGHTS"] = 1000;
    fields["TOTAL"] = "t";
    fields["OFFENSE"] = "t";
    fields["DEFENSE"] = "t";
  }
  return fields;
}

void savePrefs(string[string] fields) {
  string fileName = file_name_base + "prefs.txt";
  map_to_file(fields, fileName);
}

void main(int maxFights){
  string[string] fields = readPrefs();
  fields["MAX_FIGHTS"] = maxFights;
  print_html(process(fields));
}
