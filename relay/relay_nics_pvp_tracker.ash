script "relay_nics_pvp_tracker.ash";
notify nicnak;

import <nics_pvp_tracker.ash>

void main() {
  // defaults
  int maxFights = 1000;

  // Grab values from form
  string[string] fields = form_fields();
  if (fields contains "fightCount") {
    maxFights = to_int(fields["fightCount"]);
  }

  write("<html><body>");
  write("<form><input type='text' name='fightCount' value='" + maxFights + "'/>");
  write("<input type='submit' value='reload'/></form>");
	
  writeln(process(maxFights));
  writeln("<p><a href=\"peevpee.php\">Back to the Colosseum</a></p>");
  write("</body></html>");
}
