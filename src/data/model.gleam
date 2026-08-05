import atproto.{type DecodedRecord}
import gen/actor/defs.{type ProfileViewDetailed}
import gen/alpha/feed/play.{type AlphaFeedPlay}
import gen/repo.{type Repo}
import stats.{type StatsData}

pub type SiteData {
  SiteData(
    profile: ProfileViewDetailed,
    recent_plays: List(AlphaFeedPlay),
    plays_stats: StatsData,
    repos: List(DecodedRecord(Repo)),
    posts: List(Post),
  )
}

pub type Post {
  Post(
    title: String,
    description: String,
    slug: String,
    date: String,
    content: String,
    tags: List(String),
    draft: Bool,
    image: String,
  )
}
