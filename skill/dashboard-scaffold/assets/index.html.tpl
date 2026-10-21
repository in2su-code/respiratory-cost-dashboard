<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}}</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; padding: 24px; }
  main { max-width: 1100px; margin: 0 auto; }
  section { margin: 24px 0; }
  pre { background: #f4f4f5; padding: 12px; overflow: auto; }
</style>
</head>
<body>
<main>
  <h1>{{TITLE}}</h1>

  <!-- 지표 하나 = section 하나. data-metric 값 = build.py 의 metric_<이름> = data/<이름>.json -->
  <section data-metric="overview"><h2>overview</h2></section>
</main>

<script>
// 지표별 전용 렌더러는 여기에 renderers.<이름> = (data, el) => {...} 로 추가한다.
// 없으면 JSON 을 그대로 보여 준다.
const renderers = {};

document.querySelectorAll("section[data-metric]").forEach(async (el) => {
  const name = el.dataset.metric;
  try {
    const data = await (await fetch(`data/${name}.json`)).json();
    if (renderers[name]) renderers[name](data, el);
    else el.insertAdjacentHTML("beforeend", `<pre>${JSON.stringify(data, null, 1)}</pre>`);
  } catch (e) {
    el.insertAdjacentHTML("beforeend", `<p>data/${name}.json 을 읽지 못했습니다. python3 build.py 를 먼저 실행하세요.</p>`);
  }
});
</script>
</body>
</html>
