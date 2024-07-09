---
.title = "Minideck",
.date = @date("2024-07-09T21:16:57"),
.author = "Karitham",
.draft = false,
.layout = "post.html",
.tags = ["typst", "tech"],
---

I have always hated Microsoft Powerpoint. It's slow, you have to either fight the app on windows or use the terrible online version.
Google slides was always the *less terrible* alternative. Google slides feels slightly faster and more modern.
Still, they are overly complex and the UX is suboptimal. Both in terms of throwing text on a slide and in how they
lay it out.

Enter [minideck](https://typst.app/universe/package/minideck/). Minideck allows you to *just write code* and get slides out.
Minideck provides simple, fundamental building blocks: `pause`, `only` and `uncover`.

```
#slide[
    = Slide title
    - This thing shows on the first slide
    #show: pause
    - And this renders on the next slide
    #only(3)[- This one shows on slide 3 and never after]
    #uncover(from: 2, to: 4)[- This one shows on slide 2, 3 and 4]
]
```

In `typst` laying stuff out works with the box model just like in HTML, and it has all the convenience of floating layouts if you need to overlay layer on top of layer.

```
#slide[
    #grid(
        columns: (1fr, fr),
        align: horizon,
        gutter: 1em,
        [
            = Title

            This content describes the image next to it. They
            are approximately sized the same. Text wrapping just works.
            There is no automatic text sizing shenanigans.

            Text will never give you up.
        ],
        image("./assets/dQw4w9WgXcQ.gif")
    )
]
```

One might think

> But kar, I don't only use Google Slides by myself, I use it for group projects! I love the sync features!

Typst is *just* plain text and you can *just use git*, it's great for collaboration.

The people behind it have also built [an online collaborative editor](https://typst.app/) that wipes the floor with overleaf, its direct competitor both in terms of features and UX.

Another advantage minideck has, and by extension typst has too, is that it works well with language models. You can easily generate most of your slide deck (e.g. from your research paper), focusing only on the important parts and theming it afterwards.

There's generally a ton of advantages to [plain-text](https://sive.rs/plaintext) content, and I'm very happy to finally have found the tool that will make me ditch Google slides or Microsoft Powerpoint.
