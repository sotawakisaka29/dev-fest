import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

const sourceDirectory = 'assets/boundaries/source';
const outputDirectory = 'assets/boundaries/compact';
const coordinateScale = 100000;

function squaredSegmentDistance(point, start, end) {
  let x = start[0];
  let y = start[1];
  let dx = end[0] - x;
  let dy = end[1] - y;

  if (dx !== 0 || dy !== 0) {
    const t =
      ((point[0] - x) * dx + (point[1] - y) * dy) / (dx * dx + dy * dy);
    if (t > 1) {
      x = end[0];
      y = end[1];
    } else if (t > 0) {
      x += dx * t;
      y += dy * t;
    }
  }

  dx = point[0] - x;
  dy = point[1] - y;
  return dx * dx + dy * dy;
}

function simplifyDouglasPeucker(points, squaredTolerance) {
  const markers = new Uint8Array(points.length);
  const stack = [0, points.length - 1];
  markers[0] = 1;
  markers[points.length - 1] = 1;

  while (stack.length > 0) {
    const last = stack.pop();
    const first = stack.pop();
    let maxDistance = squaredTolerance;
    let farthestIndex = 0;

    for (let index = first + 1; index < last; index += 1) {
      const distance = squaredSegmentDistance(
        points[index],
        points[first],
        points[last],
      );
      if (distance > maxDistance) {
        farthestIndex = index;
        maxDistance = distance;
      }
    }

    if (farthestIndex !== 0) {
      markers[farthestIndex] = 1;
      stack.push(first, farthestIndex, farthestIndex, last);
    }
  }

  return points.filter((_, index) => markers[index] === 1);
}

function simplifyRing(rawRing, tolerance) {
  const points = rawRing.slice();
  if (
    points.length > 1 &&
    points[0][0] === points.at(-1)[0] &&
    points[0][1] === points.at(-1)[1]
  ) {
    points.pop();
  }
  if (points.length <= 4) return points;

  const simplified = simplifyDouglasPeucker(points, tolerance * tolerance);
  return simplified.length >= 3 ? simplified : points.slice(0, 3);
}

function outerRings(geometry) {
  if (geometry.type === 'MultiPolygon') {
    return geometry.coordinates.map((polygon) => polygon[0]);
  }
  if (geometry.type === 'Polygon') {
    return [geometry.coordinates[0]];
  }
  return [];
}

function quantizeRing(ring) {
  return ring.map(([longitude, latitude]) => [
    Math.round(longitude * coordinateScale),
    Math.round(latitude * coordinateScale),
  ]);
}

function compactFeatures(features, keyForFeature, tolerance) {
  const regions = {};
  for (const feature of features) {
    const key = keyForFeature(feature);
    if (!key) continue;
    const target = (regions[key] ??= []);
    for (const ring of outerRings(feature.geometry)) {
      target.push(quantizeRing(simplifyRing(ring, tolerance)));
    }
  }
  return regions;
}

async function readGeoJson(fileName) {
  return JSON.parse(
    await readFile(join(sourceDirectory, fileName), { encoding: 'utf8' }),
  );
}

async function writeCompactJson(path, value) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, JSON.stringify(value));
}

const prefectures = await readGeoJson('jp_prefectures.geojson');
const municipalities = await readGeoJson('jp_municipalities.geojson');

const compactPrefectures = compactFeatures(
  prefectures.features,
  (feature) => feature.properties.N03_001,
  0.003,
);
await writeCompactJson(
  join(outputDirectory, 'prefectures.json'),
  compactPrefectures,
);

const municipalityFeaturesByPrefecture = Map.groupBy(
  municipalities.features,
  (feature) => feature.properties.N03_001,
);
const manifest = {};
for (const [prefecture, features] of municipalityFeaturesByPrefecture) {
  const code = features[0].properties.N03_007.slice(0, 2);
  const fileName = `municipalities_${code}.json`;
  manifest[prefecture] = fileName;
  await writeCompactJson(
    join(outputDirectory, fileName),
    compactFeatures(
      features,
      (feature) => feature.properties.N03_004,
      0.0005,
    ),
  );
}
await writeCompactJson(join(outputDirectory, 'manifest.json'), manifest);

console.log('Compact boundary assets generated.');
