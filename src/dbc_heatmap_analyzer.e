note
	description: "[
		DBC_HEATMAP_ANALYZER - Analyzes Design by Contract coverage across the ecosystem.

		Generates heatmap data showing where contracts (require/ensure/invariant) exist.
		Heat = good (well-contracted code), Cold/dark = needs attention.

		Color scale (dark mode):
		  0%:     #1a1a1a (near-black, cold)
		  1-24%:  #2d1f3d (dark purple)
		  25-49%: #4a2c4a (muted magenta)
		  50-74%: #8b4513 (burnt orange)
		  75-89%: #cd5c00 (orange)
		  90-100%: #ff4500 (red-orange, hot)

		Usage:
			analyzer: DBC_HEATMAP_ANALYZER
			create analyzer.make
			analyzer.analyze_from_ucf (ucf)
			analyzer.generate_html_report ("dbc_heatmap.html")
	]"
	author: "Larry Rix"
	date: "$Date$"
	revision: "$Revision$"

class
	DBC_HEATMAP_ANALYZER

create
	make

feature {NONE} -- Initialization

	make
			-- Initialize analyzer
		do
			create parser.make
			create library_metrics.make (50)
			create class_metrics.make (500)
			create feature_metrics.make (5000)
		ensure
			parser_created: parser /= Void
		end

feature -- Access

	library_metrics: HASH_TABLE [DBC_LIBRARY_METRICS, STRING]
			-- Metrics by library name

	class_metrics: HASH_TABLE [DBC_CLASS_METRICS, STRING]
			-- Metrics by fully qualified class name (library.class)

	feature_metrics: ARRAYED_LIST [DBC_FEATURE_METRICS]
			-- All feature metrics

	total_features: INTEGER
			-- Total features analyzed

	total_with_require: INTEGER
			-- Features with preconditions

	total_with_ensure: INTEGER
			-- Features with postconditions

	total_classes: INTEGER
			-- Total classes analyzed

	total_with_invariant: INTEGER
			-- Classes with invariants

feature -- Analysis

	analyze_from_ucf (a_ucf: SIMPLE_UCF)
			-- Analyze all libraries in UCF configuration
		require
			ucf_valid: a_ucf.is_valid
		do
			reset_metrics
			across a_ucf.libraries as lib loop
				if not lib.resolved_path.is_empty then
					analyze_library (lib.name.to_string_8, lib.resolved_path.to_string_8)
				end
			end
			calculate_aggregates
		end

	analyze_library (a_name, a_path: STRING)
			-- Analyze a single library
		require
			name_not_empty: not a_name.is_empty
			path_not_empty: not a_path.is_empty
		local
			l_lib_metrics: DBC_LIBRARY_METRICS
			l_src_path: STRING
			l_dir: DIRECTORY
		do
			create l_lib_metrics.make (a_name, a_path)
			library_metrics.force (l_lib_metrics, a_name)

			-- Scan src directory
			l_src_path := a_path + "/src"
			create l_dir.make (l_src_path)
			if l_dir.exists then
				scan_directory (l_dir, a_name, l_lib_metrics)
			end
		end

feature -- Report Generation

	generate_html_report (a_output_path: STRING)
			-- Generate interactive HTML heatmap report
		require
			path_not_empty: not a_output_path.is_empty
		local
			l_file: SIMPLE_FILE
			l_html: STRING
		do
			l_html := build_html_report
			create l_file.make (a_output_path)
			l_file.write_text (l_html).do_nothing
		end

	generate_json: STRING
			-- Generate JSON data for external visualization
		local
			l_json: SIMPLE_JSON_OBJECT
			l_libs: SIMPLE_JSON_ARRAY
			l_lib_obj: SIMPLE_JSON_OBJECT
			l_classes: SIMPLE_JSON_ARRAY
			l_class_obj: SIMPLE_JSON_OBJECT
		do
			create l_json.make
			l_json.put_integer (total_features, "total_features").do_nothing
			l_json.put_integer (total_with_require, "total_with_require").do_nothing
			l_json.put_integer (total_with_ensure, "total_with_ensure").do_nothing
			l_json.put_integer (total_classes, "total_classes").do_nothing
			l_json.put_integer (total_with_invariant, "total_with_invariant").do_nothing
			l_json.put_integer (overall_score, "overall_score").do_nothing

			create l_libs.make
			across library_metrics as lib loop
				create l_lib_obj.make
				l_lib_obj.put_string (lib.name, "name").do_nothing
				l_lib_obj.put_integer (lib.score, "score").do_nothing
				l_lib_obj.put_string (color_for_score (lib.score), "color").do_nothing
				l_lib_obj.put_integer (lib.class_count, "class_count").do_nothing
				l_lib_obj.put_integer (lib.feature_count, "feature_count").do_nothing
				l_lib_obj.put_integer (lib.require_count, "require_count").do_nothing
				l_lib_obj.put_integer (lib.ensure_count, "ensure_count").do_nothing

				-- Add classes for this library
				create l_classes.make
				across class_metrics as cls loop
					if cls.library_name.same_string (lib.name) then
						create l_class_obj.make
						l_class_obj.put_string (cls.class_name, "name").do_nothing
						l_class_obj.put_integer (cls.score, "score").do_nothing
						l_class_obj.put_string (color_for_score (cls.score), "color").do_nothing
						l_class_obj.put_integer (cls.feature_count, "features").do_nothing
						l_class_obj.put_integer (cls.require_count, "requires").do_nothing
						l_class_obj.put_integer (cls.ensure_count, "ensures").do_nothing
						l_class_obj.put_boolean (cls.has_invariant, "has_invariant").do_nothing
						l_classes.add_object (l_class_obj).do_nothing
					end
				end
				l_lib_obj.put_array (l_classes, "classes").do_nothing
				l_libs.add_object (l_lib_obj).do_nothing
			end
			l_json.put_array (l_libs, "libraries").do_nothing

			Result := l_json.to_json_string.to_string_8
		end

feature -- Scoring

	overall_score: INTEGER
			-- Overall ecosystem DbC score (0-100)
		do
			if total_features > 0 then
				Result := ((total_with_require + total_with_ensure) * 50) // total_features
			end
			Result := Result.min (100)
		end

	color_for_score (a_score: INTEGER): STRING
			-- Get dark-mode color for score
		do
			if a_score = 0 then
				Result := "#1a1a1a"  -- Near-black (cold/dead)
			elseif a_score < 25 then
				Result := "#2d1f3d"  -- Dark purple
			elseif a_score < 50 then
				Result := "#4a2c4a"  -- Muted magenta
			elseif a_score < 75 then
				Result := "#8b4513"  -- Burnt orange
			elseif a_score < 90 then
				Result := "#cd5c00"  -- Orange
			else
				Result := "#ff4500"  -- Red-orange (hot)
			end
		end

feature {NONE} -- Implementation

	parser: EIFFEL_PARSER
			-- Eiffel source parser

	reset_metrics
			-- Reset all metrics
		do
			library_metrics.wipe_out
			class_metrics.wipe_out
			feature_metrics.wipe_out
			total_features := 0
			total_with_require := 0
			total_with_ensure := 0
			total_classes := 0
			total_with_invariant := 0
		end

	scan_directory (a_dir: DIRECTORY; a_lib_name: STRING; a_lib_metrics: DBC_LIBRARY_METRICS)
			-- Recursively scan directory for .e files
		local
			l_entries: ARRAYED_LIST [PATH]
			l_entry_name, l_entry_path: STRING
			l_file: SIMPLE_FILE
			l_subdir: DIRECTORY
		do
			a_dir.open_read
			l_entries := a_dir.entries
			across l_entries as entry loop
				l_entry_name := entry.name.to_string_8
				if not l_entry_name.same_string (".") and not l_entry_name.same_string ("..") then
					l_entry_path := a_dir.name + "/" + l_entry_name
					create l_file.make (l_entry_path)
					if l_file.is_directory then
						if not l_entry_name.starts_with (".") and not l_entry_name.same_string ("EIFGENs") then
							create l_subdir.make (l_entry_path)
							scan_directory (l_subdir, a_lib_name, a_lib_metrics)
						end
					elseif l_file.extension.same_string_general ("e") then
						analyze_file (l_entry_path, a_lib_name, a_lib_metrics)
					end
				end
			end
			a_dir.close
		end

	analyze_file (a_path, a_lib_name: STRING; a_lib_metrics: DBC_LIBRARY_METRICS)
			-- Analyze a single Eiffel file
		local
			l_file: SIMPLE_FILE
			l_content: STRING
			l_ast: detachable EIFFEL_AST
			l_class_metrics: DBC_CLASS_METRICS
			l_feature_metrics: DBC_FEATURE_METRICS
			l_has_invariant: BOOLEAN
			l_retried: BOOLEAN
		do
			if not l_retried then
				create l_file.make (a_path)
				if l_file.exists then
					l_content := l_file.read_text.to_string_8

					-- Skip empty files
					if l_content.count > 10 then
						-- Check for invariant in raw text (parser may not expose it)
						l_has_invariant := l_content.has_substring ("%Ninvariant%N") or
							l_content.has_substring ("%Ninvariant%T")

						l_ast := parser.parse_string (l_content)
						if attached l_ast as la_ast and then not la_ast.has_errors then
							across la_ast.classes as cls loop
								create l_class_metrics.make (a_lib_name, cls.name, a_path)
								l_class_metrics.set_has_invariant (l_has_invariant)

								total_classes := total_classes + 1
								a_lib_metrics.increment_class_count
								if l_has_invariant then
									total_with_invariant := total_with_invariant + 1
								end

								across cls.features as feat loop
									-- Skip attributes for DbC scoring (they don't have contracts)
									if not feat.is_attribute then
										create l_feature_metrics.make (a_lib_name, cls.name, feat.name)
										l_feature_metrics.set_has_require (not feat.precondition.is_empty)
										l_feature_metrics.set_has_ensure (not feat.postcondition.is_empty)
										feature_metrics.extend (l_feature_metrics)

										total_features := total_features + 1
										a_lib_metrics.increment_feature_count
										l_class_metrics.increment_feature_count

										if not feat.precondition.is_empty then
											total_with_require := total_with_require + 1
											a_lib_metrics.increment_require_count
											l_class_metrics.increment_require_count
										end

										if not feat.postcondition.is_empty then
											total_with_ensure := total_with_ensure + 1
											a_lib_metrics.increment_ensure_count
											l_class_metrics.increment_ensure_count
										end
									end
								end

								l_class_metrics.calculate_score
								class_metrics.force (l_class_metrics, a_lib_name + "." + cls.name)
							end
						end
					end
				end
			end
		rescue
			l_retried := True
			retry
		end

	calculate_aggregates
			-- Calculate aggregate scores for libraries
		do
			across library_metrics as lib loop
				lib.calculate_score
			end
		end

	build_html_report: STRING
			-- Build complete HTML report with D3.js visualization
		do
			create Result.make (50000)
			Result.append ("<!DOCTYPE html>%N")
			Result.append ("<html lang=%"en%">%N")
			Result.append ("<head>%N")
			Result.append ("  <meta charset=%"UTF-8%">%N")
			Result.append ("  <meta name=%"viewport%" content=%"width=device-width, initial-scale=1.0%">%N")
			Result.append ("  <title>DbC Heatmap - Simple Eiffel Ecosystem</title>%N")
			Result.append ("  <script src=%"https://d3js.org/d3.v7.min.js%"></script>%N")
			Result.append ("  <script src=%"https://unpkg.com/alpinejs@3.x.x/dist/cdn.min.js%" defer></script>%N")
			Result.append (html_styles)
			Result.append ("</head>%N")
			Result.append ("<body>%N")
			Result.append ("  <div id=%"app%" x-data=%"heatmapApp()%">%N")
			Result.append ("    <header>%N")
			Result.append ("      <h1>Design by Contract Heatmap</h1>%N")
			Result.append ("      <p class=%"subtitle%">Simple Eiffel Ecosystem</p>%N")
			Result.append ("    </header>%N")
			Result.append ("    <div class=%"summary%">%N")
			Result.append ("      <div class=%"stat%">%N")
			Result.append ("        <span class=%"value%">" + overall_score.out + "%%</span>%N")
			Result.append ("        <span class=%"label%">Overall Score</span>%N")
			Result.append ("      </div>%N")
			Result.append ("      <div class=%"stat%">%N")
			Result.append ("        <span class=%"value%">" + library_metrics.count.out + "</span>%N")
			Result.append ("        <span class=%"label%">Libraries</span>%N")
			Result.append ("      </div>%N")
			Result.append ("      <div class=%"stat%">%N")
			Result.append ("        <span class=%"value%">" + total_classes.out + "</span>%N")
			Result.append ("        <span class=%"label%">Classes</span>%N")
			Result.append ("      </div>%N")
			Result.append ("      <div class=%"stat%">%N")
			Result.append ("        <span class=%"value%">" + total_features.out + "</span>%N")
			Result.append ("        <span class=%"label%">Features</span>%N")
			Result.append ("      </div>%N")
			Result.append ("      <div class=%"stat%">%N")
			Result.append ("        <span class=%"value%">" + total_with_require.out + "</span>%N")
			Result.append ("        <span class=%"label%">Requires</span>%N")
			Result.append ("      </div>%N")
			Result.append ("      <div class=%"stat%">%N")
			Result.append ("        <span class=%"value%">" + total_with_ensure.out + "</span>%N")
			Result.append ("        <span class=%"label%">Ensures</span>%N")
			Result.append ("      </div>%N")
			Result.append ("    </div>%N")
			Result.append ("    <div class=%"legend%">%N")
			Result.append ("      <span class=%"cold%">Cold (0%%)</span>%N")
			Result.append ("      <div class=%"scale%"></div>%N")
			Result.append ("      <span class=%"hot%">Hot (100%%)</span>%N")
			Result.append ("    </div>%N")
			Result.append ("    <div id=%"visualization%"></div>%N")
			Result.append ("    <div class=%"details%" x-show=%"selectedNode%">%N")
			Result.append ("      <h3 x-text=%"selectedNode?.name%"></h3>%N")
			Result.append ("      <p>Score: <span x-text=%"selectedNode?.score + '%%'%"></span></p>%N")
			Result.append ("    </div>%N")
			Result.append ("  </div>%N")
			Result.append ("  <script>%N")
			Result.append ("    const data = " + generate_json + ";%N")
			Result.append (html_script)
			Result.append ("  </script>%N")
			Result.append ("</body>%N")
			Result.append ("</html>%N")
		end

	html_styles: STRING
			-- CSS styles for dark mode
		do
			Result := "[
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #0d1117;
      color: #c9d1d9;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
      min-height: 100vh;
    }
    header {
      text-align: center;
      padding: 2rem;
      border-bottom: 1px solid #21262d;
    }
    h1 { color: #f0f6fc; font-size: 2rem; }
    .subtitle { color: #8b949e; margin-top: 0.5rem; }
    .summary {
      display: flex;
      justify-content: center;
      gap: 2rem;
      padding: 1.5rem;
      background: #161b22;
      flex-wrap: wrap;
    }
    .stat {
      text-align: center;
      padding: 1rem;
    }
    .stat .value {
      display: block;
      font-size: 2rem;
      font-weight: bold;
      color: #ff4500;
    }
    .stat .label {
      color: #8b949e;
      font-size: 0.875rem;
    }
    .legend {
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 1rem;
      padding: 1rem;
      font-size: 0.875rem;
    }
    .legend .scale {
      width: 200px;
      height: 20px;
      background: linear-gradient(to right, #1a1a1a, #2d1f3d, #4a2c4a, #8b4513, #cd5c00, #ff4500);
      border-radius: 4px;
    }
    .cold { color: #8b949e; }
    .hot { color: #ff4500; }
    #visualization {
      padding: 2rem;
      min-height: 600px;
    }
    .node {
      cursor: pointer;
      transition: all 0.2s;
    }
    .node:hover {
      filter: brightness(1.3);
    }
    .node text {
      fill: #c9d1d9;
      font-size: 11px;
      pointer-events: none;
    }
    .link {
      stroke: #30363d;
      stroke-opacity: 0.6;
    }
    .details {
      position: fixed;
      bottom: 2rem;
      right: 2rem;
      background: #21262d;
      padding: 1rem;
      border-radius: 8px;
      border: 1px solid #30363d;
    }
    .details h3 { color: #f0f6fc; margin-bottom: 0.5rem; }
  </style>
]"
		end

	html_script: STRING
			-- JavaScript for D3.js visualization
		do
			Result := "[
    function heatmapApp() {
      return {
        selectedNode: null,
        selectNode(node) {
          this.selectedNode = node;
        }
      }
    }

    // Build hierarchical data for D3
    const root = {
      name: "Universe",
      score: data.overall_score,
      color: getColor(data.overall_score),
      children: data.libraries.map(lib => ({
        name: lib.name.replace('simple_', ''),
        fullName: lib.name,
        score: lib.score,
        color: lib.color,
        features: lib.feature_count,
        requires: lib.require_count,
        ensures: lib.ensure_count,
        children: lib.classes.slice(0, 20).map(cls => ({  // Limit classes shown
          name: cls.name,
          score: cls.score,
          color: cls.color,
          features: cls.features,
          requires: cls.requires,
          ensures: cls.ensures,
          hasInvariant: cls.has_invariant
        }))
      }))
    };

    function getColor(score) {
      if (score === 0) return '#1a1a1a';
      if (score < 25) return '#2d1f3d';
      if (score < 50) return '#4a2c4a';
      if (score < 75) return '#8b4513';
      if (score < 90) return '#cd5c00';
      return '#ff4500';
    }

    const width = document.getElementById('visualization').clientWidth || 1200;
    const height = 600;

    const svg = d3.select('#visualization')
      .append('svg')
      .attr('width', width)
      .attr('height', height);

    // Create force simulation
    const simulation = d3.forceSimulation()
      .force('link', d3.forceLink().id(d => d.name).distance(80))
      .force('charge', d3.forceManyBody().strength(-200))
      .force('center', d3.forceCenter(width / 2, height / 2))
      .force('collision', d3.forceCollide().radius(30));

    // Flatten hierarchy to nodes and links
    const nodes = [];
    const links = [];

    nodes.push({ id: root.name, ...root, radius: 40 });

    root.children.forEach(lib => {
      nodes.push({ id: lib.name, ...lib, radius: 25 });
      links.push({ source: root.name, target: lib.name });

      if (lib.children) {
        lib.children.forEach(cls => {
          const nodeId = lib.name + '.' + cls.name;
          nodes.push({ id: nodeId, ...cls, radius: 12 });
          links.push({ source: lib.name, target: nodeId });
        });
      }
    });

    const link = svg.append('g')
      .selectAll('line')
      .data(links)
      .join('line')
      .attr('class', 'link');

    const node = svg.append('g')
      .selectAll('g')
      .data(nodes)
      .join('g')
      .attr('class', 'node')
      .call(d3.drag()
        .on('start', dragstarted)
        .on('drag', dragged)
        .on('end', dragended));

    node.append('circle')
      .attr('r', d => d.radius)
      .attr('fill', d => d.color)
      .attr('stroke', d => d.score > 50 ? '#ff4500' : '#30363d')
      .attr('stroke-width', d => d.score > 75 ? 3 : 1);

    node.append('text')
      .attr('dy', d => d.radius + 12)
      .attr('text-anchor', 'middle')
      .text(d => d.name.length > 15 ? d.name.substring(0, 12) + '...' : d.name);

    node.append('title')
      .text(d => `${d.name}\nScore: ${d.score}%\nFeatures: ${d.features || 'N/A'}`);

    simulation.nodes(nodes).on('tick', ticked);
    simulation.force('link').links(links);

    function ticked() {
      link
        .attr('x1', d => d.source.x)
        .attr('y1', d => d.source.y)
        .attr('x2', d => d.target.x)
        .attr('y2', d => d.target.y);

      node.attr('transform', d => `translate(${d.x},${d.y})`);
    }

    function dragstarted(event) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      event.subject.fx = event.subject.x;
      event.subject.fy = event.subject.y;
    }

    function dragged(event) {
      event.subject.fx = event.x;
      event.subject.fy = event.y;
    }

    function dragended(event) {
      if (!event.active) simulation.alphaTarget(0);
      event.subject.fx = null;
      event.subject.fy = null;
    }
]"
		end

end
