

typedef
    MatchResult = variant<args: array<string>; invalid: void?>
    Matcher = lambda<(str: string): MatchResult>

def stringMatch(var match: string): Matcher
    return <- @ <| [[<-str]](str: string)
        if str == match 
            return <- [[MatchResult args <- [{ auto[] "" }] ]] 
        return <- [[MatchResult invalid = null]]

[export]
def main(fn: string)
    print("1\n")
    let match <- stringMatch("foo")
    print("2\n")
    debug("{match}")
    // debug(invoke(match, "foo"))
    print("3\n")
