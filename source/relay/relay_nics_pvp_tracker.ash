script "relay_nics_pvp_tracker.ash";
notify nicnak;

import <nics_pvp_tracker.ash>

void main() {

  string[string] fields = form_fields();

  if (!(fields contains "MAX_FIGHTS")) {
    // defaults
    fields["MAX_FIGHTS"] = 1000;
    fields["TOTAL"] = "t";
    fields["OFFENSE"] = "t";
    fields["DEFENSE"] = "t";
  }

  write("<html><body>");
  foreach key in fields {
    // write("Key: " + key + "Value: " + fields[key] + "<br>");
  }
  write("<p><form>");
  write("Fights to process: <input type='text' name='MAX_FIGHTS' value='" +
	fields["MAX_FIGHTS"] + "'/></br>");
  string checked;
  if (fields contains "TOTAL") { checked = "checked"; } else { checked = ""; }
  write("<input type='checkbox' name='TOTAL' value='t' " + checked + ">Total");
  if (fields contains "OFFENSE") { checked = "checked"; } else { checked = ""; }
  write("<input type='checkbox' name='OFFENSE' value='t' " + checked + ">Offense");
  if (fields contains "DEFENSE") { checked = "checked"; } else { checked = ""; }
  write("<input type='checkbox' name='DEFENSE' value='t' " + checked + ">Defense");

  write("<br><input type='submit' value='Recalculate'/></form>");

  writeln(process(fields));
  writeln("<p><a href=\"peevpee.php\">Back to the Colosseum</a></p>");
  write("</body></html>");
}
