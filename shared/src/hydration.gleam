import gen/actor/defs.{type ProfileViewDetailed}
import gen/alpha/feed/play.{type AlphaFeedPlay}
import gen/repo.{type Repo}

pub type HydrationModel {
  HydrationModel(
    profile: ProfileViewDetailed,
    plays: List(AlphaFeedPlay),
    repos: List(Repo),
  )
}
