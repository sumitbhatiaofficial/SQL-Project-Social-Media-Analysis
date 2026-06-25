use ig_clone;

-- -------------------------------------------------

select * from users;
select * from comments;
select * from follows;
select * from likes;
select * from photo_tags;
select * from photos;
select * from tags;

-- ---------------------------------------------------- OBJECTIVE QUESTIONS -------------------------------------------------

-- Objective Q1: Are there any tables with duplicate or missing null values? If so, how would you handle them?

-- checking for null values
select * from users
where id is null or username is null or created_at is null;

select * from comments
where id is null or comment_text is null or user_id is null or photo_id is null or created_at is null;

select * from follows
where follower_id is null or followee_id is null or created_at is null;

select * from likes
where user_id is null or photo_id is null or created_at is null;

select * from photo_tags
where photo_id is null or tag_id is null;

select * from photos
where id is null or image_url is null or user_id is null or created_at is null;

select * from tags
where id is null or tag_name is null or created_at is null;

-- checking duplicate values
select id, username, created_at,
count(*) as duplicate_count
from users
group by id, username, created_at
having count(*) > 1;

select id, comment_text, user_id, photo_id, created_at,
count(*) as duplicate_count
from comments
group by id, comment_text, user_id, photo_id, created_at
having count(*) > 1;

select follower_id, followee_id, created_at,
count(*) as duplicate_count
from follows
group by follower_id, followee_id, created_at
having count(*) > 1;

select user_id, photo_id, created_at,
count(*) as duplicate_count
from likes
group by user_id, photo_id, created_at
having count(*) > 1;

select photo_id, tag_id,
count(*) as duplicate_count
from photo_tags
group by photo_id, tag_id
having count(*) > 1;

select id, image_url, user_id, created_at,
count(*) as duplicate_count
from photos
group by id, image_url, user_id, created_at
having count(*) > 1;

select id, tag_name, created_at,
count(*) as duplicate_count
from tags
group by id, tag_name, created_at
having count(*) > 1;

-- Objective Q2: What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

with user_activity as
	(select
		u.id as user_id,
		u.username,
		count(distinct p.id) as total_posts,
		count(distinct l.photo_id) as total_likes_given,
		count(distinct c.id) as total_comments_made,
		(count(distinct p.id) + count(distinct l.photo_id) + count(distinct c.id)) as activity_score
	from users u
	left join photos p on u.id = p.user_id
	left join likes l on u.id = l.user_id
	left join comments c on u.id = c.user_id
	group by u.id, u.username)

select
	*,
    case
		when activity_score = 0 then 'Inactive User'
        when activity_score between 1 and 10 then 'Low Activity User'
        when activity_score between 11 and 50 then 'Moderately Active User'
        when activity_score between 51 and 150 then 'Highly Active User'
        else 'Power User'
    end as activity_distribution
from user_activity;

-- Objective Q3: Calculate the average number of tags per post (photo_tags and photos tables).

select
	round(avg(tag_count),2) as avg_tags_per_post
from (
	select
		p.id,
		count(pt.tag_id) as tag_count
	from photos p
	left join photo_tags pt on p.id = pt.photo_id
	group by p.id) as tags_per_post;

-- Objective Q4: Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.

with likes_per_user as
	(select
		p.user_id,
		count(l.photo_id) as total_likes
	from photos p
	left join likes l on p.id = l.photo_id
	group by p.user_id),

comments_per_user as 
	(select
		p.user_id,
		count(c.id) as total_comments
	from photos p
	left join comments c on p.id = c.photo_id
	group by p.user_id),

posts_per_user as
	(select
		user_id,
		count(id) as total_posts
	from photos
	group by user_id)

select
	u.id as user_id,
    u.username,
    coalesce(pu.total_posts, 0) as total_posts,
    coalesce(lu.total_likes, 0) as total_likes,
    coalesce(cu.total_comments, 0) as total_comments,
    coalesce(lu.total_likes, 0) + coalesce(cu.total_comments, 0) as total_engagement,
    coalesce(round(((coalesce(lu.total_likes, 0) + coalesce(cu.total_comments, 0) * 1.00) / nullif(pu.total_posts, 0)),2),0) as engagement_rate,
    dense_rank() over(order by ((coalesce(lu.total_likes, 0) + coalesce(cu.total_comments, 0) * 1.00) / nullif(pu.total_posts, 0)) desc) as engagement_rank
from users u
left join posts_per_user pu on u.id = pu.user_id
left join likes_per_user lu on u.id = lu.user_id
left join comments_per_user cu on u.id = cu.user_id
order by engagement_rank;

-- Objective Q5: Which users have the highest number of followers and followings?

-- users with highest number of followers
with follower_counts as
	(select
		u.id as user_id,
        u.username,
		count(f.follower_id) as number_of_followers
	from users u
	left join follows f 
    on u.id = f.followee_id
	group by u.id, u.username)
    
    select * from follower_counts
    where number_of_followers = (
		select 
			max(number_of_followers)
        from follower_counts);

-- users with highest number of followings
with following_counts as
	(select
		u.id as user_id,
        u.username,
		count(f.followee_id) as number_of_followings
	from users u
	left join follows f 
    on u.id = f.follower_id
	group by u.id, u.username)
    
    select * from following_counts
    where number_of_followings = (
		select 
			max(number_of_followings)
        from following_counts);
    
-- Objective Q6: Calculate the average engagement rate (likes, comments) per post for each user.

select
	u.id as user_id,
    u.username,
    count(distinct p.id) as total_posts,
    count(distinct l.user_id) as total_likes,
    count(distinct c.id) as total_comments,
    coalesce(round(
					(count(distinct l.user_id) + count(distinct c.id)) / count(distinct p.id),
				2),
			0) as avg_engagement_per_post
from users u
left join photos p on u.id = p.user_id
left join likes l on p.id = l.photo_id
left join comments c on p.id = c.photo_id
group by u.id, u.username
order by avg_engagement_per_post desc;

-- Objective Q7: Get the list of users who have never liked any post (users and likes tables)

select
	u.id as user_id,
    u.username,
    count(l.user_id) as likes_count
from users u
left join likes l
on u.id = l.user_id
where l.user_id is null
group by u.id;

-- Objective Q8: How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns?

with liked_photo_tags as
	(select
		l.user_id,
		l.photo_id,
		pt.tag_id
	from likes l
	join photo_tags pt on l.photo_id = pt.photo_id),

tag_categories as
	(select
		id as tag_id,
		tag_name,
		case
			when tag_name in ('happy','smile') then 'Joy & Emotions'
			when tag_name in ('stunning','dreamy') then 'Aesthetics'
			when tag_name in ('food','foodie','delicious') then 'Food'
			when tag_name in ('lol','fun','party','concert','drunk') then 'Party & Fun'
			when tag_name in ('beauty','hair') then 'Beauty'
			when tag_name in ('sunset','sunrise','landscape','beach') then 'Landscape'
			when tag_name in ('style','fashion') then 'Fashion'
			when tag_name = 'photography' then 'Photography'
			else null
		end as tag_category
	from tags),

user_interest_categories as
	(select
		lpt.user_id,
		tc.tag_category,
		count(distinct lpt.photo_id) as likes_done,
        dense_rank() over(partition by lpt.user_id order by count(distinct lpt.photo_id) desc) as category_rank
	from liked_photo_tags lpt
	join tag_categories tc on lpt.tag_id = tc.tag_id
	where tc.tag_category is not null
	group by lpt.user_id, tc.tag_category)

select
	user_id,
    tag_category as hashtag_category,
    likes_done
from user_interest_categories
where category_rank <= 3
order by user_id, likes_done desc;

-- Objective Q9: Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? 
-- How can this information guide content creation and curation strategies?

with upload_stats as
	(select
		u.id as user_id,
		u.username,
		count(p.id) as photo_uploads
	from users u
	left join photos p on u.id = p.user_id
	group by u.id, u.username),

likes_received as
	(select
		p.user_id,
		count(l.user_id) as total_likes
	from photos p
	left join likes l on p.id = l.photo_id
	group by p.user_id),

comments_received as
	(select
		p.user_id,
		count(c.id) as total_comments
	from photos p
	left join comments c on p.id = c.photo_id
	group by p.user_id),

content_engagement as
	(select
		us.user_id,
		us.username,
		us.photo_uploads,
		coalesce(lr.total_likes,0) as total_likes,
		coalesce(cr.total_comments,0) as total_comments,
		(coalesce(lr.total_likes,0) + coalesce(cr.total_comments,0)) as total_engagement,
		round(((coalesce(lr.total_likes,0) + coalesce(cr.total_comments,0)) / us.photo_uploads),2) as engagement_per_photo
	from upload_stats us
	left join likes_received lr on us.user_id = lr.user_id
	left join comments_received cr on us.user_id = cr.user_id
	where us.photo_uploads > 0)

select
	photo_uploads,
    count(user_id) as users_group,
    round(avg(total_engagement),2) as avg_total_engagement,
    round(avg(engagement_per_photo),2) as avg_engagement_per_photo
from content_engagement
group by photo_uploads
order by photo_uploads;

-- Objective Q10: Calculate the total number of likes, comments, and photo tags for each user.

with likes_received as
	(select
        p.user_id,
        count(l.user_id) as total_likes
    from photos p
    left join likes l on p.id = l.photo_id
    group by p.user_id),

comments_received as
	(select
        p.user_id,
        count(c.id) as total_comments
    from photos p
    left join comments c on p.id = c.photo_id
    group by p.user_id),

tags_used as
	(select
        p.user_id,
        count(pt.photo_id) as total_photo_tags
    from photos p
    left join photo_tags pt on p.id = pt.photo_id
    group by p.user_id)

select
    u.id as user_id,
    u.username,
    coalesce(lr.total_likes,0) as total_likes,
    coalesce(cr.total_comments,0) as total_comments,
    coalesce(tu.total_photo_tags,0) as total_photo_tags
from users u
left join likes_received lr on u.id = lr.user_id
left join comments_received cr on u.id = cr.user_id
left join tags_used tu on u.id = tu.user_id
order by u.id;

-- Objective Q11: Rank users based on their total engagement (likes, comments, shares) over a month.

with like_stats as
    (select
        photo_id,
        count(*) as like_count
    from likes
    where created_at >= date_sub(curdate(), interval 1 month)
    group by photo_id),

comment_stats as
    (select
        photo_id,
        count(*) as comment_count
    from comments
    where created_at >= date_sub(curdate(), interval 1 month)
    group by photo_id),

engagement_stats as
	(select
        u.id,
        u.username,
        sum(coalesce(ls.like_count, 0)) as total_likes,
        sum(coalesce(cs.comment_count, 0)) as total_comments,
        coalesce(sum(coalesce(ls.like_count, 0) + coalesce(cs.comment_count, 0)),0) as total_engagement
    from users u
    left join photos p
        on u.id = p.user_id
    left join like_stats ls
        on p.id = ls.photo_id
    left join comment_stats cs
        on p.id = cs.photo_id
    group by u.id, u.username)

select
    id as user_id,
    username,
    total_likes,
    total_comments,
    total_engagement,
    dense_rank() over(order by total_engagement desc) as engagement_rank
from engagement_stats
order by total_engagement desc;

-- Objective Q12: Retrieve the hashtags that have been used in posts with the highest average number of likes. 
-- Use a CTE to calculate the average likes for each hashtag first.

with hashtag_avg_likes as
	(select
		t.id as hashtag_id,
		t.tag_name as hashtag,
		avg(like_counts.total_likes) as avg_likes
	from tags t
	join photo_tags pt
	on t.id = pt.tag_id
	join 
		(select
			p.id as photo_id,
			count(l.user_id) as total_likes
		from photos p
		left join likes l
		on p.id = l.photo_id
		group by p.id
	) as like_counts
	on pt.photo_id = like_counts.photo_id
	group by t.id, t.tag_name
	order by avg_likes desc)

select
	hashtag,
    round(avg_likes, 2) as average_likes
from hashtag_avg_likes
where avg_likes = (
	select
		max(avg_likes)
    from hashtag_avg_likes);

-- Objective Q13: Retrieve the users who have started following someone after being followed by that person.

select
	f1.follower_id as user1_id,
    u1.username as user1,
    f1.followee_id as user2_id,
    u2.username as user2,
    f1.created_at as user1_followed_at,
    f2.created_at as user2_followed_back_at
from follows f1
join follows f2
	on f1.follower_id = f2.followee_id
	and f1.followee_id = f2.follower_id
join users u1
	on f1.follower_id = u1.id
join users u2
	on f1.followee_id = u2.id
where f2.created_at >= f1.created_at;

-- ---------------------------------------------------- SUBJECTIVE QUESTIONS ------------------------------------------------

-- Subjective Q1: Based on user engagement and activity levels, which users would you consider the most loyal or valuable? 
-- How would you reward or incentivize these users?

with user_posts as
	(select
		p.user_id,
		count(distinct p.id) as total_posts
	from photos p
	group by p.user_id),
    
likes_received as
	(select
		p.user_id,
		count(l.photo_id) as total_likes_received
	from photos p
	left join likes l
	on p.id = l.photo_id
	group by p.user_id),

comments_received as
	(select
		p.user_id,
		count(c.id) as total_comments_received
	from photos p
	left join comments c
	on p.id = c.photo_id
	group by p.user_id),

likes_given as    
	(select
		l.user_id,
		count(l.photo_id) as total_likes_given
	from likes l
	group by l.user_id),

comments_made as
	(select
		c.user_id,
		count(c.id) as total_comments_made
	from comments c
	group by c.user_id),

followers_count as    
	(select
		f.followee_id as user_id,
		count(f.follower_id) as total_followers
	from follows f
	group by f.followee_id)

select
	u.id as user_id,
    u.username,
    coalesce(up.total_posts, 0) as posts,
    coalesce(lr.total_likes_received, 0) as likes_received,
    coalesce(cr.total_comments_received, 0) as comments_received,
    coalesce(lg.total_likes_given, 0) as likes_given,
    coalesce(cm.total_comments_made, 0) as comments_made,
    coalesce(fc.total_followers, 0) as followers,
    round(
		(coalesce(up.total_posts, 0) * 0.10 +
		coalesce(lr.total_likes_received, 0) * 0.20 +
		coalesce(cr.total_comments_received, 0) * 0.25 +
		coalesce(lg.total_likes_given, 0) * 0.17 +
		coalesce(cm.total_comments_made, 0) * 0.25 +
		coalesce(fc.total_followers, 0) * 0.03
		),2) as loyalty_score
from users u
left join user_posts up on u.id = up.user_id
left join likes_received lr on u.id = lr.user_id
left join comments_received cr on u.id = cr.user_id
left join likes_given lg on u.id = lg.user_id
left join comments_made cm on u.id = cm.user_id
left join followers_count fc on u.id =fc.user_id
order by loyalty_score desc;

-- Subjective Q2: For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

select
	u.id,
	u.username,
    count(p.id) as post_count,
	count(distinct c.id) as comment_count,
	count(distinct l.user_id) as likes_count
from users u
left join photos p on u.id = p.user_id
left join comments c on u.id = c.user_id
left join likes l on u.id = l.user_id
where not exists (
	select
		p.id
	from photos p 
	where p.user_id = u.id)
and not exists (
	select
		l.user_id
	from likes l
	where l.user_id = u.id)
and not exists (
	select
		c.id
	from comments c
	where c.user_id = u.id)
group by u.id, u.username;

-- Subjective Q3: Which hashtags or content topics have the highest engagement rates? 
-- How can this information guide content strategy and ad campaigns?

with post_engagement as
	(select
		p.id as photo_id,
		count(distinct l.user_id) as total_likes,
		count(distinct c.id) as total_comments,
		(count(distinct l.user_id) + count(distinct c.id)) as total_engagement
	from photos p
	left join likes l on p.id = l.photo_id
	left join comments c on p.id = c.photo_id
	group by p.id),

hashtag_performance as
	(select
		t.tag_name as hashtag,
		count(distinct pt.photo_id) as total_posts,
		sum(pe.total_likes) as total_likes,
		sum(pe.total_comments) as total_comments,
		sum(pe.total_engagement) as total_engagement,
		round(
			avg(pe.total_engagement), 2
		) as avg_engagement_per_post
	from tags t
	join photo_tags pt on t.id = pt.tag_id
	join post_engagement pe on pt.photo_id = pe.photo_id
	group by t.id, t.tag_name)
    
select
	hashtag,
    total_posts,
    total_likes,
    total_comments,
    total_engagement,
    avg_engagement_per_post,
    rank() over( order by avg_engagement_per_post desc) as engagement_rank
from hashtag_performance
order by engagement_rank, total_posts desc;

-- Subjective Q4: Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times?
-- How can these insights inform targeted marketing campaigns?

with likes_per_photo as
	(select
		photo_id,
		count(user_id) as like_count
	from likes
	group by photo_id),

comments_per_photo as
	(select
		photo_id,
		count(id) as comment_count
	from comments
	group by photo_id),

user_post_engagement as
	(select
		u.id as user_id,
        u.username,
		p.id as photo_id,
		date(p.created_at) as posting_date,
		hour(p.created_at) as posting_hour,
		coalesce(l.like_count, 0) as total_likes,
		coalesce(c.comment_count, 0) as total_comments
	from users u
    left join photos p on u.id = p.user_id
	left join likes_per_photo l on p.id = l.photo_id
	left join comments_per_photo c on p.id = c.photo_id)

select
	user_id,
    username,
    posting_date,
    posting_hour,
	count(photo_id) as total_posts,
	sum(total_likes) as total_likes,
	sum(total_comments) as total_comments,
    sum(total_likes) + sum(total_comments) as total_engagement,
	round(
		(sum(total_likes) + sum(total_comments)) * 1.0 / count(photo_id)
	, 2) as avg_engagement_per_post
from user_post_engagement
group by user_id, username, posting_date, posting_hour
having total_posts > 0
order by avg_engagement_per_post desc;

-- Subjective Q5: Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns?
-- How would you approach and collaborate with these influencers?

with follower_stats as
	(select
		followee_id as user_id,
		count(follower_id) as total_followers
	from follows
	group by followee_id),
    
post_stats as
	(select
		user_id,
		count(id) as total_posts
	from photos
	group by user_id),

like_stats as
	(select
		p.user_id,
		count(l.user_id) as total_likes
	from photos p
	left join likes l on p.id = l.photo_id
	group by p.user_id),

comment_stats as
	(select
		p.user_id,
		count(c.id) as total_comments
	from photos p
	left join comments c on p.id = c.photo_id
	group by p.user_id),

engagement_stats as
	(select
		u.id as user_id,
		u.username,
		coalesce(fs.total_followers,0) as followers,
		coalesce(ps.total_posts,0) as total_posts,
		coalesce(ls.total_likes,0) as total_likes,
		coalesce(cs.total_comments,0) as total_comments,
		(coalesce(ls.total_likes,0) + coalesce(cs.total_comments,0)) as total_engagement
	from users u
	left join follower_stats fs on u.id = fs.user_id
	left join post_stats ps on u.id = ps.user_id
	left join like_stats ls on u.id = ls.user_id
	left join comment_stats cs on u.id = cs.user_id)
    
select
	*,
    round(total_engagement * 1.0 / total_posts, 2) as engagement_rate,
    round(
		((followers * 0.40) + ((total_engagement * 1.0 / total_posts) * 0.50) + (total_posts * 0.10)),
        2) as influencer_score,
    rank() over(order by round(
		((followers * 0.40) + ((total_engagement * 1.0 / total_posts) * 0.50) + (total_posts * 0.10)),
        2) desc) as influencer_rank
from engagement_stats
where total_posts > 0
order by influencer_rank;

-- Subjective Q6: Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations?

with post_stats as
	(select
		user_id,
		count(distinct id) as total_posts
	from photos
	group by user_id),

like_stats as
	(select
		user_id,
		count(distinct photo_id) as likes_given
	from likes
	group by user_id),
    
comment_stats as
	(select
		user_id,
		count(distinct id) as comments_made
	from comments
	group by user_id),

follower_stats as
	(select
		followee_id as user_id,
		count(distinct follower_id) as total_followers
	from follows
	group by followee_id),

hashtag_stats as
	(select
		p.user_id,
		count(pt.tag_id) as hashtag_interactions
	from photos p 
	left join photo_tags pt
	on p.id = pt.photo_id
	group by p.user_id),

user_engagement as
	(select
		u.id as user_id,
		u.username,
		coalesce(ps.total_posts,0) as total_posts,
		coalesce(ls.likes_given,0) as likes_given,
		coalesce(cs.comments_made,0) as comments_made,
		coalesce(fs.total_followers,0) as total_followers,
		coalesce(hs.hashtag_interactions,0) as hashtag_interactions
	from users u
	left join post_stats ps on u.id = ps.user_id
	left join like_stats ls on u.id = ls.user_id
	left join comment_stats cs on u.id = cs.user_id
	left join follower_stats fs on u.id = fs.user_id
	left join hashtag_stats hs on u.id = hs.user_id)

select
	user_id,
    username,
    total_posts,
    likes_given,
    comments_made,
    total_followers,
    hashtag_interactions,
    case
		when total_posts >= 5 and hashtag_interactions >= 10 then 'Content Creator'
        when likes_given >= 75 and comments_made >=50 and total_posts >= 1 then 'Highly Engaged User'
        when total_posts = 0 and likes_given >= 200 then 'Active Consumer'
        when total_posts = 0 and likes_given = 0 and comments_made = 0 then 'Inactive User'
        else 'Casual User'
    end as user_segment
from user_engagement;

-- Subjective Q8: How can you use user activity data to identify potential brand ambassadors or advocates who could help promote Instagram's initiatives or events?

with follower_stats as
	(select
		followee_id as user_id,
		count(follower_id) as total_followers
	from follows
	group by followee_id),

post_stats as 
	(select
		user_id,
		count(id) as total_posts
	from photos
	group by user_id),
        
likes_received as 
	(select
		p.user_id,
		count(l.user_id) as total_likes_received
	from photos p
	left join likes l on p.id = l.photo_id
	group by p.user_id),

comments_received as 
	(select
		p.user_id,
		count(c.id) as total_comments_received
	from photos p
	left join comments c on p.id = c.photo_id
	group by p.user_id),
    
engagement_stats as
	(select
		u.id as user_id,
		coalesce(total_likes_received,0) as total_likes_received,
		coalesce(total_comments_received,0) as total_comments_received
	from users u
	left join likes_received lr on u.id = lr.user_id
	left join comments_received cr on u.id = cr.user_id),
    
likes_given as
	(select
		user_id,
		count(user_id) as likes_given
	from likes
	group by user_id),
    
comments_made as 
	(select
		user_id,
		count(id) as comments_made
	from comments
	group by user_id),
    
activity_stats as
	(select
		u.id as user_id,
		coalesce(likes_given,0) as likes_given,
		coalesce(comments_made,0) as comments_made
	from users u
	left join likes_given lg on u.id = lg.user_id
	left join comments_made cm on u.id = cm.user_id)
    
select
	u.id as user_id,
    u.username,
    coalesce(fs.total_followers,0) as total_followers,
    coalesce(ps.total_posts,0) as total_posts,
    es.total_likes_received,
    es.total_comments_received,
    ast.likes_given,
    ast.comments_made,
    round(
		(coalesce(fs.total_followers,0) * 0.30 +
		coalesce(ps.total_posts,0) * 0.10 +
		es.total_likes_received * 0.20 +
		es.total_comments_received * 0.30 +
		ast.likes_given * 0.05 +
		ast.comments_made * 0.05),2
    ) as ambassador_score
from users u
left join follower_stats fs on u.id = fs.user_id
left join post_stats ps on u.id = ps.user_id
left join engagement_stats es on u.id = es.user_id
left join activity_stats ast on u.id = ast.user_id
where coalesce(ps.total_posts,0) > 0
order by ambassador_score desc;

-- Subjective Q10: Assuming there's a "User_Interactions" table tracking user engagements, 
-- how can you update the "Engagement_Type" column to change all instances of "Like" to "Heart" to align with Instagram's terminology?

create table user_interactions (
	interaction_id int auto_increment primary key,
    user_id int,
    photo_id int,
    engagement_type varchar(50),
	interaction_date date);
    
insert into user_interactions (user_id, photo_id, engagement_type, interaction_date)
values
(1, 1, 'Like', '2026-05-21'),
(2,2, 'Comment', '2026-05-21'),
(3,3, 'Share', '2026-05-21'),
(4,4, 'Like', '2026-05-21'),
(5,5, 'Like', '2026-05-21');

update user_interactions
set engagement_type = 'Heart'
where engagement_type = 'Like';

select * from user_interactions;