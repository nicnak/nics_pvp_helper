script "relay_nics_pvp_tracker.ash";
notify nicnak;

import <nics_pvp_tracker.ash>

void main() {

  string[string] fields = form_fields();

  write("<html><body>");
  foreach key in fields {
    //write("Key: " + key + "Value: " + fields[key] + "<br>");
  }

  if (fields contains "RESET_PREFS") {
    string[string] empty;
    savePrefs(empty);
    fields = readPrefs();
  } else if (fields contains "MAX_FIGHTS") {
    savePrefs(fields);
  } else {
    fields = readPrefs();
  }

  write("<p><form>");
  write("Fights to process: <input type='text' name='MAX_FIGHTS' value='" +
	fields["MAX_FIGHTS"] + "' size=5 /></br>");
  string checked;
  if (fields contains "TOTAL") { checked = "checked"; } else { checked = ""; }
  write("<input type='checkbox' name='TOTAL' value='t' " + checked + " />Total");
  if (fields contains "OFFENSE") { checked = "checked"; } else { checked = ""; }
  write("<input type='checkbox' name='OFFENSE' value='t' " + checked + " />Offense");
  if (fields contains "DEFENSE") { checked = "checked"; } else { checked = ""; }
  write("<input type='checkbox' name='DEFENSE' value='t' " + checked + " />Defense<br>");
  write("Restrict to player: <input type='text' name='PLAYER_RESTRICT' value='" +
	fields["PLAYER_RESTRICT"] + "' size=10 /></br>");

  write("<input type='submit' value='Recalculate'/></form>");

  write(process(fields));

  write("<p><a href=\"peevpee.php\">Back to the Colosseum</a></p>");
  write("<p><form><input type='submit' value='Reset Preferences' name='RESET_PREFS'/></form>");
  write("</body></html>");
}
