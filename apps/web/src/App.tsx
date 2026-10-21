const highlights = [
  {
    icon: "✳",
    title: "Made for your moment",
    text: "A menu that feels as considered as the room you’re staying in.",
  },
  {
    icon: "⌁",
    title: "Every detail, in sync",
    text: "From your first look to the last course, hospitality flows naturally.",
  },
  {
    icon: "አ",
    title: "Your language, your way",
    text: "A more welcoming dining experience, with Amharic and English in mind.",
  },
];

function App() {
  return (
    <main className="min-h-screen overflow-hidden bg-[#f8f7f4] text-[#202823]">
      <nav className="mx-auto flex max-w-7xl items-center justify-between px-6 py-6 sm:px-10 lg:px-16">
        <a
          className="flex items-center gap-3"
          href="#top"
          aria-label="SmartServe home"
        >
          <span className="grid size-10 place-items-center rounded-full bg-[#173e35] text-lg text-[#e7c78b]">
            s
          </span>
          <span className="text-lg font-semibold tracking-tight">
            smartserve<span className="text-[#b4814b]">.</span>
          </span>
        </a>
        <a
          className="rounded-full border border-[#d9d7ce] px-5 py-2.5 text-sm font-medium transition hover:border-[#173e35] hover:bg-white"
          href="mailto:hello@smartserve.app"
        >
          Get in touch <span aria-hidden="true">↗</span>
        </a>
      </nav>

      <section
        id="top"
        className="relative mx-auto grid max-w-7xl items-center gap-12 px-6 pb-20 pt-12 sm:px-10 md:grid-cols-[1.04fr_.96fr] md:pb-28 md:pt-16 lg:px-16"
      >
        <div className="relative z-10 max-w-2xl">
          <div className="mb-7 inline-flex items-center gap-2 rounded-full border border-[#e2ded4] bg-white/70 px-4 py-2 text-xs font-semibold uppercase tracking-[.14em] text-[#6d755f]">
            <span className="size-2 rounded-full bg-[#b68b57]"></span> A new
            kind of hotel dining
          </div>
          <h1 className="font-display text-[clamp(3.3rem,7.4vw,6.3rem)] leading-[.99] tracking-[-.055em]">
            Hospitality,
            <br />
            <span className="italic text-[#a87949]">made thoughtful.</span>
          </h1>
          <p className="mt-7 max-w-lg text-base leading-7 text-[#70766f] sm:text-lg sm:leading-8">
            A more personal way to discover, order, and enjoy hotel dining.
            Thoughtfully connected, from the first hello to the last bite.
          </p>
          <div className="mt-9 flex flex-wrap items-center gap-4">
            <a
              href="#experience"
              className="group inline-flex items-center gap-3 rounded-full bg-[#173e35] px-6 py-3.5 text-sm font-semibold text-white shadow-lg shadow-[#173e35]/10 transition hover:-translate-y-0.5 hover:bg-[#225346]"
            >
              Discover SmartServe{" "}
              <span className="transition group-hover:translate-x-1">→</span>
            </a>
            <span className="text-sm text-[#83877f]">
              For guests &amp; hotel teams
            </span>
          </div>
          <div className="mt-14 flex items-center gap-4 border-t border-[#e5e2d9] pt-6 text-sm text-[#73796f]">
            <span className="font-display text-2xl text-[#a87949]">Selam</span>
            <span className="h-7 w-px bg-[#dedbd1]"></span>
            <span>Welcome, in every language.</span>
          </div>
        </div>

        <div className="relative mx-auto w-full max-w-[540px] md:ml-auto">
          <div className="absolute -right-10 -top-12 size-48 rounded-full bg-[#ead9bc]/45 blur-3xl"></div>
          <div className="absolute -bottom-16 -left-8 size-48 rounded-full bg-[#c5d4c3]/50 blur-3xl"></div>
          <div className="relative overflow-hidden rounded-[2rem] bg-[#d7d8cc] shadow-[0_28px_80px_-35px_rgba(35,47,37,.35)]">
            <img
              className="h-[440px] w-full object-cover sm:h-[550px]"
              src="https://images.unsplash.com/photo-1414235077428-338989a2e8c0?auto=format&fit=crop&w=1200&q=85"
              alt="An intimate, warmly lit restaurant table set for dinner"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-[#12221c]/70 via-transparent to-[#12221c]/5"></div>
            <div className="absolute left-6 top-6 rounded-full border border-white/40 bg-white/75 px-4 py-2 text-xs font-semibold tracking-wide text-[#27362c] backdrop-blur-md">
              A seat at the table
            </div>
            <div className="absolute inset-x-0 bottom-0 p-7 text-white sm:p-9">
              <div className="mb-3 text-xs font-semibold uppercase tracking-[.2em] text-[#e8cd9e]">
                Considered hospitality
              </div>
              <p className="max-w-sm font-display text-3xl leading-tight sm:text-4xl">
                The little things
                <br />
                make a stay.
              </p>
              <div className="mt-6 flex items-center gap-3 text-xs text-white/80">
                <span className="grid size-8 place-items-center rounded-full border border-white/40">
                  ✳
                </span>{" "}
                Dining, made more human
              </div>
            </div>
          </div>
          <div className="absolute -bottom-7 right-5 rounded-2xl border border-white/70 bg-white/90 px-5 py-4 shadow-xl backdrop-blur">
            <div className="font-display text-xl text-[#173e35]">
              Ameseginalehu
            </div>
            <div className="mt-1 text-[11px] uppercase tracking-[.15em] text-[#868a80]">
              Thank you · አመሰግናለሁ
            </div>
          </div>
        </div>
      </section>

      <section
        id="experience"
        className="border-t border-[#e9e6de] bg-white/55 px-6 py-16 sm:px-10 md:py-20 lg:px-16"
      >
        <div className="mx-auto max-w-7xl">
          <div className="mb-10 flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[.2em] text-[#a87949]">
                The SmartServe feeling
              </p>
              <h2 className="mt-3 font-display text-3xl tracking-tight sm:text-4xl">
                A warmer welcome, at every step.
              </h2>
            </div>
            <p className="max-w-sm text-sm leading-6 text-[#7b8078]">
              Good service should feel effortless. We’re bringing the whole
              dining experience a little closer together.
            </p>
          </div>
          <div className="grid gap-4 md:grid-cols-3">
            {highlights.map((item, index) => (
              <article
                key={item.title}
                className="rounded-3xl border border-[#e9e6df] bg-[#fbfaf8] p-6 sm:p-7"
              >
                <div className="mb-8 flex items-center justify-between">
                  <span className="grid size-11 place-items-center rounded-2xl bg-[#edf0e9] font-display text-xl text-[#49624c]">
                    {item.icon}
                  </span>
                  <span className="text-xs tracking-[.18em] text-[#b6b7ae]">
                    0{index + 1}
                  </span>
                </div>
                <h3 className="font-display text-xl">{item.title}</h3>
                <p className="mt-2 text-sm leading-6 text-[#7b8078]">
                  {item.text}
                </p>
              </article>
            ))}
          </div>
        </div>
      </section>
      <footer className="mx-auto flex max-w-7xl flex-col gap-3 px-6 py-7 text-xs text-[#8b8e85] sm:flex-row sm:items-center sm:justify-between sm:px-10 lg:px-16">
        <span>
          © {new Date().getFullYear()} SmartServe. Thoughtfully served.
        </span>
        <span>Made for the moments that matter.</span>
      </footer>
    </main>
  );
}

export default App;
