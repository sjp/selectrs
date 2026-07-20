# selectrs' parse-error wording is stable

    Code
      css_to_xpath(" ")
    Condition
      Error:
      ! Unable to parse the CSS selector " ": EmptySelector
        |
        |  
        |  ^

---

    Code
      css_to_xpath("div > ")
    Condition
      Error:
      ! Unable to parse the CSS selector "div > ": DanglingCombinator
        |
        | div > 
        |       ^

---

    Code
      css_to_xpath("foo!")
    Condition
      Error:
      ! Unable to parse the CSS selector "foo!": UnexpectedToken(Delim('!'))
        |
        | foo!
        |    ^

---

    Code
      css_to_xpath("foo|#bar")
    Condition
      Error:
      ! Unable to parse the CSS selector "foo|#bar": ExplicitNamespaceUnexpectedToken(IDHash("bar"))
        |
        | foo|#bar
        |     ^

---

    Code
      css_to_xpath("[rel i]")
    Condition
      Error:
      ! Unable to parse the CSS selector "[rel i]": UnexpectedTokenInAttributeSelector(Ident("i"))
        |
        | [rel i]
        |     ^

---

    Code
      css_to_xpath("a[rel!=nofollow]")
    Condition
      Error:
      ! Unable to parse the CSS selector "a[rel!=nofollow]": UnexpectedTokenInAttributeSelector(Delim('!'))
        |
        | a[rel!=nofollow]
        |      ^

---

    Code
      css_to_xpath("e:contains(\"foo\")")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:contains(\"foo\")": UnsupportedPseudoClassOrElement("contains")
        |
        | e:contains("foo")
        |            ^

---

    Code
      css_to_xpath("e::before")
    Condition
      Error:
      ! Unable to parse the CSS selector "e::before": UnsupportedPseudoClassOrElement("before")
        |
        | e::before
        |   ^

---

    Code
      css_to_xpath("e:lang(-)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:lang(-)": UnsupportedPseudoClassOrElement("lang")
        |
        | e:lang(-)
        |         ^

---

    Code
      css_to_xpath("e:lang(*-CH)")
    Condition
      Error:
      ! The CSS selector "e:lang(*-CH)" uses the :lang() language range "*-CH" (a wildcard outside the final subtag), which this translator does not support

---

    Code
      css_to_xpath("col || td")
    Condition
      Error:
      ! The CSS selector "col || td" uses the `||` column combinator, which this translator does not support

---

    Code
      css_to_xpath("e:is(> a)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:is(> a)": EmptySelector
        |
        | e:is(> a)
        |      ^

---

    Code
      css_to_xpath("e:has(a:has(b))")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:has(a:has(b))": InvalidState
        |
        | e:has(a:has(b))
        |             ^

---

    Code
      css_to_xpath("*:first-of-type")
    Condition
      Error:
      ! The CSS selector "*:first-of-type" uses an of-type pseudo-class on the universal selector `*`, which this translator does not support

---

    Code
      css_to_xpath("e:nth-child(3 7)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:nth-child(3 7)": UnexpectedToken(Number { has_sign: false, value: 7.0, int_value: Some(7) })
        |
        | e:nth-child(3 7)
        |              ^

---

    Code
      css_to_xpath("e:nth-child(2.5)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:nth-child(2.5)": UnexpectedToken(Number { has_sign: false, value: 2.5, int_value: None })
        |
        | e:nth-child(2.5)
        |                ^

