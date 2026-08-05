import data/transport/core
import gleeunit/should

// --- classify_status ---

pub fn classify_429_is_transient_test() {
  core.classify_status(429, "rate limited")
  |> should.equal(Error(core.Transient("rate limited")))
}

pub fn classify_500_is_transient_test() {
  core.classify_status(500, "boom")
  |> should.equal(Error(core.Transient("boom")))
}

pub fn classify_503_is_transient_test() {
  core.classify_status(503, "unavailable")
  |> should.equal(Error(core.Transient("unavailable")))
}

pub fn classify_404_is_permanent_test() {
  core.classify_status(404, "not found")
  |> should.equal(Error(core.Permanent("not found")))
}

pub fn classify_400_is_permanent_test() {
  core.classify_status(400, "bad request")
  |> should.equal(Error(core.Permanent("bad request")))
}

// --- decide ---

pub fn decide_success_succeeds_test() {
  core.decide(Ok("ok"), 3) |> should.equal(core.Succeeded("ok"))
}

pub fn decide_permanent_gives_up_immediately_test() {
  core.decide(Error(core.Permanent("p")), 3) |> should.equal(core.GivenUp("p"))
}

pub fn decide_transient_retries_while_attempts_remain_test() {
  core.decide(Error(core.Transient("t")), 3) |> should.equal(core.Retry("t"))
}

pub fn decide_transient_gives_up_on_last_attempt_test() {
  core.decide(Error(core.Transient("t")), 1) |> should.equal(core.GivenUp("t"))
}
