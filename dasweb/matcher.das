options indenting = 2
module matcher shared
require strings

typedef
  Handler = lambda<(message: string): string>
  MatchResult = variant<success: int; invalid: void?>

class Matcher
  def abstract match(str: string): MatchResult


class StringMatch : Matcher
  matchStr : string
  def StringMatch(str: string)
    matchStr = str
  def override match(str: string): MatchResult
    if str == matchStr
      return <- [[MatchResult success = length(str) ]]
    return <- [[MatchResult invalid = null]]
