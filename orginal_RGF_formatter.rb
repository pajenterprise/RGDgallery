require 'nokogiri'
require 'open-uri'


HOME = "http://www.reddit.com"
HTMLEND = "/r/redditgetsdrawn"

# A typical post will look like this unformatted:
# 	<div class="entry unvoted">
#   	<p class="title"><a class="title " href="http://imgur.com/LVJy5YG" tabindex="1">Please draw my grandparents! It was just their 50th anniversary!</a>&#32;
#     	<span class="domain">(<a href="/domain/imgur.com/">imgur.com</a>)</span>
#     </p>
#     <p class="tagline">submitted&#32;
#     	<time title="Sun Mar 9 14:18:03 2014 UTC" datetime="2014-03-09T14:18:03+00:00">16 hours</time>&#32;ago&#32;by&#32;<a href="http://www.reddit.com/user/jgordon02" class="author id-t2_4ja0p">jgordon02</a>
#     	<span class="userattrs"></span>
#     </p>
#     <ul class="flat-list buttons">
#     	<li class="first"><a class="comments" href="http://www.reddit.com/r/redditgetsdrawn/comments/1zysx2/please_draw_my_grandparents_it_was_just_their/" target="_parent">143 comments</a>
#     	</li>
#     	<li class="share">
#     		<span class="share-button toggle" style=""><a class="option active login-required" href="#" tabindex="100">share</a><a class="option " href="#">cancel</a>
#     		</span>
#     	</li>
#     </ul>
#     <div class="expando" style='display: none'>
#     	<span class="error">loading...</span>
#     </div>
#   </div>
#
#
# Use this example as a guide for what CSSquery you'll need to get at the information you're looking for.
class Post
  attr_reader :post
	attr_accessor :submitter,:ref_link,:comments_link,:title,:timestamp,:artworks
	def initialize(post)
		@post          = post
		@ref_link      = self.get_ref_link
		@title         = self.get_title
		@submitter     = self.get_submitter
		@timestamp     = self.get_timestamp
		@comments_link = self.get_comments_link
		@artworks      = self.get_artworks(get_first_level_comments)
	end

	# This method already works. It grabs the href of the reference image and formats it properly
	# so the image link is usable.
	def get_ref_link
		ref_links = post.css('.title a').map { |link| link["href"]}
		ref_links.map { |link|
			unless link.include?("/domain/") || link.include?("/r/redditgetsdrawn/")
				if link.include?("i.imgur")
					link =~ /\.(png|jpg|gif)/ ? link : link.insert(-1, ".jpg")
				elsif link.include?("imgur")
					link_gallery = Nokogiri::HTML(open(link))
					img_link = link_gallery.css('link').select{|this_link| this_link["rel"]=="image_src" }[0]["href"]
				else
					link
				end
			end
		}[0]
	end

	# Phase 1 Method
	#
	# return the title of the post
	# Example "<a class="title " href="http://imgur.com/LVJy5YG" tabindex="1">Please draw my grandparents! It was just their 50th anniversary!</a>&#32;"
	# get_title will only return "Please draw my grandparents! It was just their 50th anniversary!"
	#
	def get_title
		post.css('p.title a.title').map {|title| title.text}[0]
	end

	# Phase 1 Method
	#
	# return the submitter as a Submitter object (See Submitter class)
	# Example "<a href="http://www.reddit.com/user/jgordon02" class="author id-t2_4ja0p">jgordon02</a>"
	# submitter.username => jgordon02
	# submitter.user_link => http://www.reddit.com/user/jgordon02
	#
	def get_submitter
		Submitter.new(post) # Be weary of creating dependencies like these which don't promote easy future changes. Suggest reading of Chapter 3 Practical OO Design in Ruby 
	end

	# Phase 1 Method
	#
	# return the timestamp of when the reference was originially submitted
	# Example <p class="tagline">submitted&#32;
 	#           <time title="Sun Mar 9 14:18:03 2014 UTC" datetime="2014-03-09T14:18:03+00:00">16 hours</time>&#32;ago&#32;by&#32;<a href="http://www.reddit.com/user/jgordon02" class="author id-t2_4ja0p">jgordon02</a>
  	#           <span class="userattrs"></span>
  	#         </p>
  	# get_timestamp => "2014-03-09T14:18:03+00:00"
  	#
	def get_timestamp
		time = post.at_css('time')["datetime"]
	end

	# Phase 1 Method
	#
	# return the link as a string to the comments page
	# Example <li class="first"><a class="comments" href="http://www.reddit.com/r/redditgetsdrawn/comments/1zysx2/please_draw_my_grandparents_it_was_just_their/" target="_parent">143 comments</a>
	# get_comments_link => "http://www.reddit.com/r/redditgetsdrawn/comments/1zysx2/please_draw_my_grandparents_it_was_just_their/"
	def get_comments_link
		comments_link = post.at_css('.comments')["href"]
	end

	# Phase 1.5 Method (Complete all Phase 1 methods before working on this)
	#
	# This method will be for phase 1.5 where we need to return all of the first level comments after going to @comments_link
	# The comments will be stored in an array.
	def get_first_level_comments
		comments_page = Nokogiri::HTML(open(comments_link))
		child = comments_page.css('.child .entry')
		comments = comments_page.css('.entry').select{|link| 
			!(child.include?(link))
		}
		comments[1..-1] # index 0 would be the initial post so we return all but the index 0
	end

	# Phase 1.5 Method (Complete all Phase 1 methods before working on this)
	#
	# Within this method we will call get_first_level_comments and then format the information into Artwork objects
	def get_artworks(comments) # given an array all of the first_level_comments
		art = comments.map{|comment| Artwork.new(comment)}
	end

end



# Represents the Submitter of the post
class Submitter
	attr_accessor :username, :user_link
	def initialize(post)
		@post = post
		@username  = get_username
		@user_link = get_user_link
	end

	def get_username
		authors = @post.css('.author')
		username = authors.map {|author| author.text.strip}[0]
	end

	def get_user_link
		user_link = "http://www.reddit.com/user/#{username}"
	end

end





#
# An Example Artwork comment
#
#
#  <div class="entry unvoted">
#  	<div class="collapsed" style="display:none">
#  		<a href="#" class="expand" onclick="return showcomment(this)">[+]</a>
#  		<a href="http://www.reddit.com/user/StorytimeWithDudly" class="author gray id-t2_bie55">StorytimeWithDudly</a>
#  		<span class="userattrs"></span> <span class="score dislikes">28 points</span><span class="score unvoted">29 points</span>
#  		<span class="score likes">30 points</span> 
#  		<time title="Tue Mar 11 16:55:29 2014 UTC" datetime="2014-03-11T16:55:29+00:00">1 hour</time> ago  <a href="#" class="expand" onclick="return showcomment(this)">(1 child)</a>
#  	</div>
#  	<div class="noncollapsed">
#  		<p class="tagline">
#  			<a href="#" class="expand" onclick="return hidecomment(this)">[–]</a>
#  			<a href="http://www.reddit.com/user/StorytimeWithDudly" class="author id-t2_bie55">StorytimeWithDudly</a>
#  			<span class="userattrs"></span> <span class="score dislikes">28 points</span><span class="score unvoted">29 points</span>
#  			<span class="score likes">30 points</span> <time title="Tue Mar 11 16:55:29 2014 UTC" datetime="2014-03-11T16:55:29+00:00">1 hour</time> ago
#  		</p>
#  		<form action="#" class="usertext" onsubmit="return post_form(this, 'editusertext')" id="form-t1_cfzxh8dzu4">
#  			<input type="hidden" name="thing_id" value="t1_cfzxh8d">
#  			<div class="usertext-body">
#  				<div class="md">
#  					<p>Second submission to this sub! I really need skin tones...<br><a href="http://imgur.com/lzByaHa">http://imgur.com/lzByaHa</a>      </p>
#  				</div>
#  			</div>
#  		</form>
#  		<ul class="flat-list buttons">
#  			<li class="first">
#  				<a href="http://www.reddit.com/r/redditgetsdrawn/comments/2052uh/my_boyfriend_during_his_african_childhood/cfzxh8d" class="bylink" rel="nofollow">permalink</a>
#  			</li>
#  		</ul>
#  	</div>
#  </div>

class Artwork
	attr_accessor :comment, :link, :submitter, :timestamp, :upvotes
	def initialize(comment)
		@comment = comment
		@link = self.get_art_link
		@submitter = self.get_submitter
		@timestamp = self.get_timestamp
		@upvotes = self.get_upvotes
	end

	# Returns the href for the artwork: if the link is a gallery then the method must open that gallery and grab the first picture in said gallery
	def get_art_link
		links = comment.at_css('.md p a') == nil ? nil : links = comment.at_css('.md p a').attributes["href"].value
		unless links == nil
			if links.include?("i.imgur")
				links =~ /\.(png|jpg|gif)/ ? links : links.insert(-1, ".jpg")
			elsif links.include?("imgur")
				link_gallery = Nokogiri::HTML(open(links))
				img_link = link_gallery.css('link').select{|this_link| this_link["rel"]=="image_src" }[0]["href"]
			else
				links
			end
		end
	end

	# Returns a Submitter object which includes username and user_link
	def get_submitter
		Submitter.new(@comment)
	end

	# Returns the timestamp for the when the art was submitted
	def get_timestamp
		time = comment.at_css('time')["datetime"]
	end

	# Returns the number of upvotes as an int
	# Example <span class="score likes">30 points</span> 
	# get_upvotes => 30
	def get_upvotes
	    upvotes = comment.at_css('.likes')
	    if upvotes.to_s.empty?
	    	nil
	    else
	    	upvotes.children.text.to_s.split(" ")[0].to_i
	    end
	end
end

def test_output(posts_formatted)
	posts_formatted.each{|posts| 
		posts.artworks.select{|art|
			!art.link == nil
		}
	}
	posts_formatted.each_with_index { |post, i|
		unless post.ref_link == nil || post.artworks.empty?
			puts "**************************************************************"
			puts "*****************ORIGINAL REFERENCE POST *********************"
			puts "**************************************************************"
			puts "\n\n\nThe post in posts_formatted array at index ##{i}:\n"
			puts "Title"
			puts "posts_formatted[#{i}].title : #{post.title}"
			puts "\nReference picture"
			puts "posts_formatted[#{i}].ref_link : #{post.ref_link}"
			puts "\nSubmitter"
			puts "posts_formatted[#{i}].submitter.username : #{post.submitter.username}"
			puts "posts_formatted[#{i}].submitter.user_link : #{post.submitter.user_link}"
			puts "\nTime Submitted"
			puts "posts_formatted[#{i}].timestamp : #{post.timestamp}"
			puts "\nLink to the comments section of the post"
			puts "posts_formatted[#{i}].comments_link : #{post.comments_link}"
			puts "**************************************************************"
			puts "**************************************************************"
			puts "\n\nIterating through the artworks array of this post we get"
			post.artworks.each_with_index{|artwork, index|
				unless artwork.link == nil
					puts "--------------------------------------------------------------"
					puts "\nArtwork at index ##{index}"
					puts "Artwork Link"
					puts "posts_formatted[#{i}].artworks[#{index}].link : #{artwork.link}"
					puts "\nArtwork Submitter"
					puts "posts_formatted[#{i}].artworks[#{index}].submitter.username : #{artwork.submitter.username}"
					puts "posts_formatted[#{i}].artworks[#{index}].submitter.user_link : #{artwork.submitter.user_link}"
					puts "\nArtwork Originially Posted"
					puts "posts_formatted[#{i}].artworks[#{index}].timestamp : #{artwork.timestamp}"
					puts "\nArtwork Upvotes Count"
					puts "posts_formatted[#{i}].artworks[#{index}].upvotes : #{artwork.upvotes}"
					puts "--------------------------------------------------------------"
				end
			}
		end
	}
end

def make_HTML_test(posts_formatted)
	html_file = "<!doctype html>
				<head>
					<title>/r/redditgetsdrawn Gallery</title>
				</head>
				<body>"
	posts_formatted.each{|posts| 
		posts.artworks.select{|art|
			!art.link == nil
		}
	}

	posts_formatted.each_with_index do |post, i|
		unless post.ref_link == nil || post.artworks.empty?
			html_file += "<div class=\"post\">"
			html_file += "<p>#{post.title}</p>"
			html_file += "<img src=\"#{post.ref_link}\" \/>"
			post.artworks.each_with_index do |artwork, index|
				html_file += "<div class=\"artworks\">"
				unless artwork.link == nil
					html_file += "<div class=\"art\">"
					html_file += "<img src=\"#{artwork.link}\"\/>"
					html_file += "<\/div>"
				end
				html_file += "<\/div>"
			end
			html_file += "<\/div>"
		end
	end
	html_file += "<\/body>"
	html_file += "<\/html>"
	Dir.mkdir("RGD_HTML") unless File::directory?("RGD_HTML")
	open("RGD_HTML/RGD_Gallery.html", 'wb') do |file|
		file.write(html_file)
	end
end

doc = Nokogiri::HTML(open(HOME + HTMLEND))
posts = doc.css('.entry')
posts_formatted = []


# Adds the Post object to the posts_formatted array
posts.each_with_index{|post,index|
	posts_formatted << Post.new(post)
}

test_output(posts_formatted)
make_HTML_test(posts_formatted)
