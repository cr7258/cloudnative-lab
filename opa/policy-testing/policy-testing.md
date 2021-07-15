## Policy Testing


```sh
❯ opa test . -v
FAILURES
--------------------------------------------------------------------------------
data.authz.test_post_allowed: FAIL (213.471µs)

  query:1                 Enter data.authz.test_post_allowed = _
  example_test.rego:3     | Enter data.authz.test_post_allowed
  example_test.rego:4     | | Fail data.authz.allow with input as {"method": "POST", "path": ["users"]}
  query:1                 | Fail data.authz.test_post_allowed = _

SUMMARY
--------------------------------------------------------------------------------
data.authz.test_post_allowed: FAIL (213.471µs)
data.authz.test_get_anonymous_denied: PASS (104.177µs)
data.authz.test_get_user_allowed: PASS (190.39µs)
data.authz.test_get_another_user_denied: PASS (108.074µs)
--------------------------------------------------------------------------------
PASS: 3/4
FAIL: 1/4
```