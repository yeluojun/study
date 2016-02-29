## 一. 创建任务

```ruby
  task :example_one do
    puts ‘this is task one’
  end
``` 

在Rakefile文件所在的目录来执行这些任务：

$ rake example_one

”this is task one“

## 二. 创建有依赖关系的任务

```ruby
  task :base_example do
    puts 'this is base example'
  end
  
  task :other_example => :base_example do
    pus 'this is other example'
  end
  
  task :another_example => other_example do
    puts 'this is another example'
  end
  
```

运行：

**$ rake base_example**

     “this is base example”

**$ rake other_example**

    "this is base example"

    "this is other example"

**$ rake another_example**

    "this is base example"

    "this is other example"

    "this is another example"
    
    
## 命名空间

```ruby
namespace :article do
  desc 'create a article'  # 任务的描述
  task :create_article do
    puts 'create A article'
  end
end
```

运行：

**$ rake -T**

     rake article: create_article                            # create a article
  

**$ rake article: create_article**

    "create A article"
    
    
## 在 rails 中使用 rake

rake文件放在 lib/tasks目录，如 lib/tasks/one.rake
    
    



