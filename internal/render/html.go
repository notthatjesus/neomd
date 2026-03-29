package render

import (
	"bytes"
	"fmt"

	"github.com/yuin/goldmark"
	"github.com/yuin/goldmark/extension"
	"github.com/yuin/goldmark/renderer/html"
)

// htmlTemplate is a minimal, self-contained email wrapper.
// Derived from the listmonk template at:
// /home/sspaeti/git/sspaeti.com/listmonk/misc/email-template.html
const htmlTemplate = `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<style>
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;line-height:1.6;color:#333;margin:0;padding:8px 16px;text-align:left}
a{color:#3150AA;text-decoration:underline}
h1,h2,h3{color:#24292e;margin:1.2em 0 .4em;line-height:1.3}
h1{font-size:22px}h2{font-size:18px}h3{font-size:16px}
p,ul,ol{font-size:15px;margin:0 0 1em}
code{background:#f6f8fa;padding:2px 4px;border-radius:3px;font-family:monospace;font-size:85%%}
pre{background:#f6f8fa;padding:12px;border-radius:4px;overflow:auto;font-family:monospace;font-size:85%%;line-height:1.4}
blockquote{border-left:3px solid #ddd;color:#666;margin:0 0 1em;padding-left:1em}
hr{border:0;border-bottom:1px solid #eee;margin:20px 0}
img{max-width:100%%;height:auto}
</style>
</head>
<body>
%s
</body>
</html>`

// md is the goldmark renderer with GFM extensions.
var md = goldmark.New(
	goldmark.WithExtensions(extension.GFM),
	goldmark.WithRendererOptions(html.WithHardWraps()),
)

// ToHTML converts a Markdown string to a complete HTML email document.
func ToHTML(markdown string) (string, error) {
	var fragment bytes.Buffer
	if err := md.Convert([]byte(markdown), &fragment); err != nil {
		return "", fmt.Errorf("markdown to html: %w", err)
	}
	return fmt.Sprintf(htmlTemplate, fragment.String()), nil
}
