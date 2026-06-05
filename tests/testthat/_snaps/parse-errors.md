# selectrs' parse-error wording is stable

    Code
      css_to_xpath(" ")
    Condition
      Error:
      ! Unable to parse the CSS selector " ": EmptySelector (at 1:2)

---

    Code
      css_to_xpath("div > ")
    Condition
      Error:
      ! Unable to parse the CSS selector "div > ": DanglingCombinator (at 1:7)

---

    Code
      css_to_xpath("foo!")
    Condition
      Error:
      ! Unable to parse the CSS selector "foo!": UnexpectedToken(Delim('!')) (at 1:4)

---

    Code
      css_to_xpath("foo|#bar")
    Condition
      Error:
      ! Unable to parse the CSS selector "foo|#bar": ExplicitNamespaceUnexpectedToken(IDHash("bar")) (at 1:5)

---

    Code
      css_to_xpath("[rel i]")
    Condition
      Error:
      ! Unable to parse the CSS selector "[rel i]": UnexpectedTokenInAttributeSelector(Ident("i")) (at 1:5)

---

    Code
      css_to_xpath("a[rel!=nofollow]")
    Condition
      Error:
      ! Unable to parse the CSS selector "a[rel!=nofollow]": UnexpectedTokenInAttributeSelector(Delim('!')) (at 1:6)

---

    Code
      css_to_xpath("e:contains(\"foo\")")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:contains(\"foo\")": UnsupportedPseudoClassOrElement("contains") (at 1:12)

---

    Code
      css_to_xpath("e::before")
    Condition
      Error:
      ! Unable to parse the CSS selector "e::before": UnsupportedPseudoClassOrElement("before") (at 1:3)

---

    Code
      css_to_xpath("e:lang(-)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:lang(-)": UnsupportedPseudoClassOrElement("lang") (at 1:9)

---

    Code
      css_to_xpath("col || td")
    Condition
      Error:
      ! The CSS selector "col || td" uses the `||` column combinator, which selectrs does not support

---

    Code
      css_to_xpath("e:is(> a)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:is(> a)": EmptySelector (at 1:6)

---

    Code
      css_to_xpath("e:has(a:has(b))")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:has(a:has(b))": InvalidState (at 1:13)

---

    Code
      css_to_xpath("*:first-of-type")
    Condition
      Error:
      ! The CSS selector "*:first-of-type" uses an of-type pseudo-class on the universal selector `*`, which selectrs does not support

---

    Code
      css_to_xpath("e:nth-child(3 7)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:nth-child(3 7)": UnexpectedToken(Number { has_sign: false, value: 7.0, int_value: Some(7) }) (at 1:14)

---

    Code
      css_to_xpath("e:nth-child(2.5)")
    Condition
      Error:
      ! Unable to parse the CSS selector "e:nth-child(2.5)": UnexpectedToken(Number { has_sign: false, value: 2.5, int_value: None }) (at 1:16)

