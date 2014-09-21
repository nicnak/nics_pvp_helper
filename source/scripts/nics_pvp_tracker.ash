script "nics_pvp_tracker.ash";
notify nicnak;

string viewPattern = "a href\=\"(peevpee\.php\\?action\=log.*?lid\=(\\d+).*?)\".*?m</small></td><td><small>(.*?)</small>";
string playersPattern = "<a href=\"showplayer.php\\?who=\\d+\"><b>(.*?)</b></a> calls out <a href=\"showplayer.php\\?who=\\d+\"><b>(.*?)</b></a> for battle!";		
string contestPattern = "<tr[a-zA-Z0-9/=\":. ]*?>\s*?<td[a-zA-Z0-9/=\":. ]*?>\s*?(<img[a-zA-Z0-9/=\":. _]*?>)?\s*?</td>.*?<center>\s*?Round \\d+: <b[a-zA-Z0-9/=\":. ]*?>(.*?)</b>\s*?<div[a-zA-Z0-9/=\":. ]*?>.*?</div>\s*?</center>\s*?<p>(.*?)</td>\s*?<td[a-zA-Z0-9/=\":. ]*?>\s*?(<img[a-zA-Z0-9/=\":. _]*?>)?\s*?</td>\s*?</tr>";
string this_player = to_lower_case(my_name());
string greeting = "<p>Welcome to <a href=\"showplayer.php\?who=1655960\">NicNak</a>'s PVP tracker. Credit to <a href=\"showplayer.php\?who=2205257\">Vhaeraun<a> for his great bookkeeper script which I snagged some bits of code from.";
string file_name_base = this_player + "_nics_pvp_tracker_";

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
  MiniStat[string] minis;
  int[string] lootStolen;
  int[string] lootLost;
  int fameTaken;
  int oFame;
  int dFame;
  int swagger;
  int flowers;
  int stats;
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
  StoredRound[string] rounds;
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

string TR(string s) {
  return "<tr>" + s + "</tr>\n";
}

string miniStatStyle(int percent) {
  string color = "#000000";
  if (percent < 20) {
    color = "#d73027";
  } else if (percent < 40) {
    color = "#fc8d59";
  } else if (percent < 60) {
    color = "#91bfdb";
  } else if (percent < 80) {
    color = "#4575b4";
  }

  return "style='color:" + color + "'";
}

string formatMiniStat(MiniStat mStat, string mini, string[string] fields) {
  int totalFights = mStat.offense.count + mStat.defense.count;
  string row = "";
  if (totalFights > 0) {
    int totalWins = mStat.offense.win + mStat.defense.win + mStat.defense.tie;
    int totalLoss = mStat.offense.loss + mStat.defense.loss + mStat.offense.tie;
    int totalPercent = truncate(to_float(totalWins)/totalFights*100);

    row += "<td>" + mini + "</td>";

    if (fields contains "TOTAL") {
      row += "<td>" + totalFights + "</td>";
      row += "<td>" + totalWins + ":" + totalLoss + "</td>";
      row += "<td " + miniStatStyle(totalPercent) + ">" + totalPercent + "%</td>";
    }

    if (fields contains "OFFENSE") {
      row += "<td>" + mStat.offense.count + "</td>";
      if (mStat.offense.count > 0) {
	int percent = truncate(to_float(mStat.offense.win) / mStat.offense.count * 100);
	row += "<td>" + mStat.offense.win + ":" + mStat.offense.loss + "(" + mStat.offense.tie + ")</td>";
	row += "<td " + miniStatStyle(percent) + ">" + percent + "%</td>";
      } else {
	row += "<td></td><td></td>";
      }
    }

    if (fields contains "DEFENSE") {
      row += "<td>" + mStat.defense.count + "</td>";
      if (mStat.defense.count > 0) {
	int percent = truncate(to_float(mStat.defense.win + mStat.defense.tie) / mStat.defense.count * 100);
	row += "<td>" + mStat.defense.win + "(" + mStat.defense.tie + "):" + mStat.defense.loss + "</td>";
	row += "<td " + miniStatStyle(percent) + ">" + percent + "%</td>";
      } else {
	row += "<td></td><td></td>";
      }
    }
  }
  return row;
}

int countLootMap(int[string] loot) {
  int count = 0;
  foreach key in loot {
    count += loot[key];
  }
  return count;
}

string formatAvg(float top, int bottom) {
  if (bottom == 0) {
    return "";
  }
  return "" + round(100.0 * top / bottom) / 100.0;
}

string formatResults(string[string] fields) {
  string html = "<p>";
  html += "<table border='1' cellpadding='2' cellspacing='2'><thead>";
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
  html += "</tbody><tfoot>";
  html += TR(formatMiniStat(player_stat.overall, "Total Fights", fields));
  html += "</tfoot></table>";

  int oFights = player_stat.overall.offense.count;
  int dFights = player_stat.overall.defense.count;
  int tFights = oFights + dFights;
  if (tFights > 0) {
    html += "<p>You stole " + player_stat.fameTaken + " fame, " +
      player_stat.flowers + " flowers, and " +
      countLootMap(player_stat.lootStolen) + " pieces of loot. " +
      "Lost " + player_stat.stats + " stats and " +
      countLootMap(player_stat.lootLost) + " pieces of loot. " +
      "Your overall fame changed by " + (player_stat.oFame + player_stat.dFame) + ".";

    html += "<p><table><tbody>";
    html += "<tr><th colspan='2'>Average per Attack</th></tr>";
    html += "<tr><td>Fame Taken</td><td>" + formatAvg(player_stat.fameTaken, oFights) + "</td></tr>";
    html += "<tr><td>Fame</td><td>" + formatAvg(player_stat.oFame, oFights) + "</td></tr>";
    html += "<tr><td>Flowers</td><td>" + formatAvg(player_stat.flowers, oFights) + "</td></tr>";
    html += "<tr><td>Swagger</td><td>" + formatAvg(player_stat.swagger, oFights) + "</td></tr>";
    html += "<tr><td>Stats</td><td>" + formatAvg(player_stat.stats, oFights) + "</td></tr>";
    html += "<tr><td>Phat Loots</td><td>" + formatAvg(countLootMap(player_stat.lootStolen), oFights) + "</td></tr>";
    html += "<tr><th colspan='2'>Average per Defend</th></tr>";
    html += "<tr><td>Fame</td><td>" + formatAvg(player_stat.dFame, dFights) + "</td></tr>";
    html += "<tr><td>Phat Loots</td><td>" + formatAvg(countLootMap(player_stat.lootLost) * -1.0, dFights) + "</td></tr>";
    html += "</tbody></table>";
  }

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

void accumulateMiniStats(StoredFight thisFight) {
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

void accumulateRewardStats(string rewardStr, boolean attacking) {
  matcher m;
  m = create_matcher("([+-]\\d+)&nbsp;Fame", rewardStr);
  if (m.find()) {
    int fame = to_int(m.group(1));
    if (attacking) {
      player_stat.oFame += fame;
      if (fame > 0) {
	player_stat.fameTaken += fame;
      }
    } else {
      player_stat.dFame += fame;
    }
  }

  m = create_matcher("[+](\\d+)&nbsp;Swagger", rewardStr);
  if (m.find()) {
    player_stat.swagger += to_int(m.group(1));
  }

  m = create_matcher("[+](\\d+)&nbsp;Flower", rewardStr);
  if (m.find()) {
    player_stat.flowers += to_int(m.group(1));
  }

  m = create_matcher("([-]\\d+)&nbsp;Stats", rewardStr);
  if (m.find()) {
    player_stat.stats += to_int(m.group(1));
  }

  m = create_matcher("Lost&nbsp;(.*)", rewardStr);
  if (m.find()) {
    player_stat.lootLost[m.group(1)] += 1;
  }

  m = create_matcher("Stole&nbsp;(.*)", rewardStr);
  if (m.find()) {
    player_stat.lootStolen[m.group(1)] += 1;
  }
}

string process(string[string] fields) {
  verifySettings();
  int maxFights = to_int(fields["MAX_FIGHTS"]);

  string fileName = file_name_base + getCurrentSeason() + ".txt";
  StoredFight[string] storedFights;
  file_to_map(fileName, storedFights);

  string archive = visit_url("peevpee.php?place=logs&mevs=0&oldseason=0&showmore=1");

  matcher logMatcher = create_matcher(viewPattern, archive); 
  int fightCount = 0;
  int fightsMatched = 0;
  while (logMatcher.find() && fightCount < maxFights) {
    fightCount += 1;
    string oneFight = group(logMatcher,1);
    string fightId = group(logMatcher,2);
    string fightReward = group(logMatcher,3);

    if (!(storedFights contains fightId)) {
      storedFights[fightId] = processFight(oneFight);
    }
    string playerRestrict = to_lower_case(fields["PLAYER_RESTRICT"]);
    if (playerRestrict != "" &&
	playerRestrict != storedFights[fightId].attacker &&
	playerRestrict != storedFights[fightId].defender) {
      continue;
    }

    fightsMatched += 1;
    accumulateMiniStats(StoredFights[fightId]);
    accumulateRewardStats(fightReward, StoredFights[fightId].attacking);
  }
  map_to_file(storedFights, fileName);

  string page;
  page += greeting;
  page += "<p>PvP Stats for the most recent " + fightCount + " fights";
  if (fightsMatched != fightCount) {
    page += "<br>Filter matched " + fightsMatched + " fights";
  }
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
