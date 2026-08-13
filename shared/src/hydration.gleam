import atproto.{type DecodedRecord}
import gen/actor/defs.{type ProfileViewDetailed}
import gen/feed/play.{type FeedPlay}
import gen/repo.{type Repo}

pub type HydrationModel {
  HydrationModel(
    profile: ProfileViewDetailed,
    plays: List(FeedPlay),
    repos: List(DecodedRecord(Repo)),
  )
}
