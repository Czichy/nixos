--- office.yazi – rich preview for Office documents in yazi
--
-- Supported formats (by MIME type):
--   application/msword                                                (.doc)
--   application/vnd.openxmlformats-officedocument.wordprocessingml.*  (.docx)
--   application/vnd.oasis.opendocument.text                          (.odt)
--   application/vnd.oasis.opendocument.spreadsheet                   (.ods)
--   application/vnd.oasis.opendocument.presentation                  (.odp)
--   application/vnd.openxmlformats-officedocument.spreadsheetml.*    (.xlsx)
--   application/vnd.openxmlformats-officedocument.presentationml.*   (.pptx)
--   application/vnd.ms-excel                                         (.xls)
--   application/vnd.ms-powerpoint                                    (.ppt)
--   application/rtf                                                  (.rtf)
--
-- Conversion chain (first success wins):
--   1. pandoc  -s <file> -t plain        (handles docx, odt, rtf, epub, …)
--   2. docx2txt <file> -                 (docx only, lighter than pandoc)
--   3. catdoc  <file>                    (legacy .doc)
--   4. odt2txt <file>                    (odt/ods/odp)
--   5. libreoffice --headless --cat      (last resort, slow but universal)

local M = {}

-- Try each converter in order; return on first success.
local function convert(file, area)
	-- Determine file extension for fallback heuristics
	local ext = file.name:match("%.(%w+)$")
	ext = ext and ext:lower() or ""

	-- Build an ordered list of conversion commands to try.
	-- Each entry: { cmd_path, {args…} }
	local strategies = {}

	-- 1) pandoc – best quality, handles docx/odt/rtf/epub
	table.insert(strategies, {
		cmd = "pandoc",
		args = { "-s", tostring(file.url), "-t", "plain", "--wrap=auto", "--columns=" .. area.w },
	})

	-- 2) docx2txt – lightweight, docx only
	if ext == "docx" then
		table.insert(strategies, {
			cmd = "docx2txt",
			args = { tostring(file.url), "-" },
		})
	end

	-- 3) catdoc – legacy .doc
	if ext == "doc" then
		table.insert(strategies, {
			cmd = "catdoc",
			args = { "-w", tostring(file.url) },
		})
	end

	-- 4) odt2txt – ODF formats
	if ext == "odt" or ext == "ods" or ext == "odp" then
		table.insert(strategies, {
			cmd = "odt2txt",
			args = { tostring(file.url) },
		})
	end

	-- 5) libreoffice headless – universal last resort
	table.insert(strategies, {
		cmd = "libreoffice",
		args = { "--headless", "--cat", tostring(file.url) },
	})

	for _, s in ipairs(strategies) do
		local child, err = Command(s.cmd)
			:args(s.args)
			:stdout(Command.PIPED)
			:stderr(Command.NULL)
			:spawn()

		if child then
			local output, _ = child:wait_with_output()
			if output and output.status and output.status.success and output.stdout and #output.stdout > 0 then
				return output.stdout
			end
		end
	end

	return nil
end

function M:peek(job)
	local text = convert(job.file, job.area)

	if not text then
		-- Nothing worked – show a hint instead of an empty preview
		local lines = {
			"[Office Document]",
			"",
			"No suitable converter found.",
			"Install one of: pandoc, docx2txt, catdoc, odt2txt, libreoffice",
		}
		ya.preview_widgets(job, {
			ui.Text(lines):area(job.area),
		})
		return
	end

	-- Truncate very long output to avoid blocking the UI
	local max_bytes = job.area.w * job.area.h * 4
	if #text > max_bytes then
		text = text:sub(1, max_bytes) .. "\n\n[… truncated …]"
	end

	-- Split into lines and skip to the requested offset (for scrolling)
	local lines = {}
	for line in text:gmatch("[^\n]*") do
		table.insert(lines, line)
	end

	local skip = job.skip or 0
	local visible = {}
	for i = skip + 1, math.min(#lines, skip + job.area.h) do
		table.insert(visible, lines[i])
	end

	ya.preview_widgets(job, {
		ui.Text(visible):area(job.area),
	})
end

function M:seek(job)
	local units = job.units
	ya.manager_emit("peek", {
		tostring(math.max(0, cx.active.preview.skip + units)),
		only_if = tostring(job.file.url),
	})
end

return M
