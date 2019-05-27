#变量名称规定
#json* 索引拆分次数
#count* 计数器
#cycle* 循环跳出

book1=$@
if [ -z ${book1} ]
then
    read -p "请输入书籍变量:" book1
fi
#函数
function manifest_fun()
{   #epub文件列表追加
    manifest=$(echo ${manifest}'<item id="'${1}'" href="'${2}'" media-type="'${3}'" />')
}
function spine_fun()
{   #epub主体文件读取顺序 1.url
    spine=$(echo ${spine}'<itemref idref="'${1}'" linear="yes"/>')
}
function navpoint_fun()
{    #目录生成  1.id 2.title 3.url
    if [ "${4}" != y ] ;then local a='</navPoint>'
    fi
    echo '<navPoint id="'$1'"><navLabel><text>'$2'</text></navLabel><content src="'$3'" />'$a  >> epub/book/toc.ncx
}
function 随机()
{
    #local a=$(echo $RANDOM % 20|bc);echo "暂停${a}s" >&2;echo $a
    echo 0
}


while [ -n "$(echo ${1}|sed -n '/^[0-9][0-9]*$/p')" ]
do
    title=$1
    metadata=$(curl http://v2.api.dmzj.com/novel/${title}.json)  #获取书籍元数据
    json0=$(curl http://v2.api.dmzj.com/novel/chapter/${title}.json) #获取索引json
    #初始化变量
    bookname=$(echo ${metadata}|jq .name -r)   #书名
    authors=$(echo ${metadata}|jq .authors -r) #作者
    introduction=$(echo ${metadata}|jq .introduction -r) #书籍简介
    cover=$(echo ${metadata}|jq .cover -r) #封面图片链接
    types=$(echo ${metadata}|jq .types|jq -r .[0]|xargs -d / printf "%s;") #标签
    count2=0
    json1=$(echo ${json0}|jq .[${count2}]) #拆分json
    
    #epub文件结构生成
    mkdir -p ${bookname}&&cd ${bookname}
    mkdir -p epub&&mkdir -p epub/META-INF
    echo -n "application/epub+zip"> epub/minetype
    echo "PD94bWwgdmVyc2lvbj0iMS4wIj8+Cjxjb250YWluZXIgdmVyc2lvbj0iMS4wIiB4bWxucz0idXJuOm9hc2lzOm5hbWVzOnRjOm9wZW5kb2N1bWVudDp4bWxuczpjb250YWluZXIiPgogICAgPHJvb3RmaWxlcz4KICAgICAgICA8cm9vdGZpbGUgZnVsbC1wYXRoPSJib29rL2luZGV4Lm9wZiIKICAgICAgICAgICAgbWVkaWEtdHlwZT0iYXBwbGljYXRpb24vb2VicHMtcGFja2FnZSt4bWwiIC8+CiAgICA8L3Jvb3RmaWxlcz4KPC9jb250YWluZXI+Cg=="|base64 -d > epub/META-INF/container.xml  #生成容器文件
    mkdir -p epub/book
    mkdir -p epub/book/image
    wget -t 0 ${cover} -O epub/book/image/cover.jpg
    manifest_fun ncx toc.ncx application/x-dtbncx+xml   #追加索引文件
    manifest_fun cover_image image/cover.jpg image/jpeg #追加封面图片文件

    
    echo '<?xml version="1.0" encoding="UTF-8"?><package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="epub"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf"><dc:identifier id="epub">'"urn:uuid:$(uuidgen||cat /proc/sys/kernel/random/uuid)"'</dc:identifier><dc:title>'"${bookname}"'</dc:title><dc:language>'"${LANG%.*}"'</dc:language><dc:subject>'"${types}"'</dc:subject><dc:description>'"${introduction}"'</dc:description><dc:creator>'"${authors}"'</dc:creator><meta name="cover" content="cover_image"/></metadata>' > epub/book/index.opf #初始化包装文件
    echo '<?xml version="1.0" encoding="utf-8"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head></head><docTitle><text>'"${bookname}"'</text></docTitle><navMap>' > epub/book/toc.ncx  #初始化目录索引文件
    echo '<?xml version="1.0" encoding="utf-8"?><!DOCTYPE html><html><head>><meta charset="utf-8" /><title>'"${bookname}"'</title></head><body><p id="title_t"><img src="image/cover.jpg" /></p><h1>'${bookname}'</h1></body></html>' > epub/book/title.html   #生成标题文件
    manifest_fun title_cover title.html application/xhtml+xml  #追加标题文件
    navpoint_fun title_title ${bookname} title.html#title_t y  #目录生成(根）
    spine_fun title.html  #载入顺序 标题1

	
    
    while [ "${json1:5:9}" == "volume_id" ]
    do
	count2=$(echo "${count2}+1"|bc)
	volume=$(echo ${json1}|jq .id) #获取卷id
	volume_name=$(echo ${json1}|jq .volume_name -r) #获取卷名
	json2=$(echo ${json1}|jq .chapters -r)#获取卷索引
	count3=0
	json3=$(echo ${json2}|jq .[${count3}])


	#epub,html生成
	echo '<?xml version="1.0" encoding="utf-8"?><!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><meta charset="utf-8" /><title>'"${bookname}-${volume_name}"'</title></head><body><h1 id='"${volume}"'>'"${volume_name}"'</h1>'  > epub/book/${volume}.html  #生成html头
	navpoint_fun volume_${volume} "${volume_name}" ${volume}.html  y #追加链接至目录文件 （2）
	manifest_fun ${volume} ${volume}.html application/xhtml+xml     #追加当前卷html入包装文件
	spine_fun ${volume}.html  #载入文件顺序列表

	
	while [ "${json3:5:10}" == "chapter_id" ]
	do
	    count3=$(echo "${count3}+1"|bc)
	    chapter=$(echo ${json3}|jq .chapter_id)  #获取章节id
	    chapter_name=$(echo ${json3}|jq .chapter_name -r)  #获取章节名
#___________wget -t 0  https://v3api.dmzj.com/novel/download/${title}_${volume}_${chapter}.txt -O ${title}_${volume}_${chapter}.txt #下载正文
	    json3=$(echo ${json2}|jq .[${count3}])
	    
	    #epub，html
	    echo '<h2 id="'"${volume}_${chapter}"'">'"${chapter_name}"'</h2>' >> epub/book/${volume}.html  #生成章节头
	    text_chapter=$(cat ${title}_${volume}_${chapter}.txt)
	    image_download=$(echo ${title}|sed 's#https://xs.dmzj.com#\n&#g'|sed 's#"./>#\n#g'|grep --color=no xs.dmzj.com)  #筛选插画url
	    navpoint_fun id${chapter} "${chapter_name}" ${volume}.html#${volume}_${chapter} #目录输出


	    rows=0 #预定义图片变量
	    while [ -n "${image_download}" ]
	    do
		rows=$(echo "${rows}+1"|bc)
		image_url=$(echo "${image_down}"|sed -n "${rows}p")
		wget -t 0  ${image_url}  -O epub/book/image/${volume}_${chapter}_${rows}.${image_url##*.} 
		text_chapter=$(echo "test_chapter"|sed "s%${image_url}%image/${volume}_${chapter}_${rows}.${image_url##*.}%g"|sed 's#<img#\n<p>& width="90%"#g'|sed 's#"./>#&</p>#g')
		manifest_fun ${volume}_${chapter}_${rows} image/${volume}_${chapter}_${rows}.${image_url##*.}  image/jpeg  #列出文件
		sleep $(随机) #随机暂停s秒
	    done   #章节图
		 #|tr '\n' ' '|sed 's#<br */>\r* *<br */>#\n#g'|sed 's#^#<p>#g'|sed 's#$#</p>#g'|sed 's#^<p> *</p>$# #g'|sed 's#<br */># #g'|sed "1d" >>epub/book/${volume}.html
		 #|tr '\n' ' '|sed 's#<br */>\r* *<br */>#\n#g'|sed 's#^#<p>#g'|sed 's#$#</p>#g'|sed '1d'>> epub/book/${volume}.html
	    #sed 's#<br */>#\n#g'|sed '/^\r*$/d'|sed "s#^#<p>#g"|sed "s%$%</p>%g"|sed "1d" >>
	    ${text_chapter}
	    sleep $(随机)
	done   #章之间
	json1=$(echo ${json0}|jq .[${count2}])
	echo '</body></html>' >> epub/book/${volume}.html #卷结束
	echo '</navPoint>' >> epub/book/toc.ncx  #卷目录结束
    done  #卷之间
    shift
    #epub 生成xml结束
    echo '</navPoint></navMap></ncx>' >> epub/book/toc.ncx #结束书目录
    echo '<manifest>'"${manifest}"'</manifest>' >> epub/book/index.opf #文件列表索引结束
    echo '<spine>'"${spine}"'</spine>' >> epub/book/index.opf #加载顺序列表索引结束
    echo '<guide></guide></package>' >> epub/book/index.opf  #结束包装文件
    cd epub&&zip -r ../../${bookname}完全原样.epub book  META-INF  minetype  #打包epub
    cd .. #返回脚本执行时路径

done #各书之间
