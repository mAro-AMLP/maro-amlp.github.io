---
layout: page
icon: fas fa-file-import
title: Submit a Feed
permalink: /submit/
order: 2
---

<form action="https://github.com/kiranprasad2001/hive/issues/new" method="get" target="_blank">
  <label for="rss-url">RSS Feed URL:</label>
  <input type="url" id="rss-url" name="title" placeholder="Enter RSS feed URL here" required>
  <input type="hidden" name="body" value="Please add this feed to blog_sources.yml">
  <button type="submit">Submit</button>
</form>