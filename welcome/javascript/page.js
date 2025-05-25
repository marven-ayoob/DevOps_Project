
// Handling the product menu 
let ourProduct = document.getElementById("product");
let productMenu = document.getElementById("product-menu");
ourProduct.onclick = function () {
    productMenu.style.display = "flex";
}
document.addEventListener('click', (event) => {
    if (!ourProduct.contains(event.target) && !productMenu.contains(event.target)) {
        productMenu.style.display = "none";    }
});

//Handling Home content animation
let homeContent = document.getElementById("home-content");
// console.log("hola");
setTimeout(function() {
    homeContent.style.display = "block";
}, 2000);


// // Handling the toggle menu
// let toggleMenuIcon = document.getElementById("toggle");
// let navMenu = document.querySelector("nav ul");
// toggleMenuIcon.onclick = function () {
//     toggleMenu(navMenu);
//     toggleMenu(productMenu); // Toggle product menu as well
// }

// document.addEventListener('click', (event) => {
//     if (!ourProduct.contains(event.target) && !productMenu.contains(event.target)) {
//         productMenu.style.display = "none";    
//     }
//     if (!toggleMenuIcon.contains(event.target) && !navMenu.contains(event.target)) {
//         navMenu.style.display = "none";    
//     }
// });

// function toggleMenu(element) {
//     if (element.style.display === "flex") {
//         element.style.display = "none";
//     } else {
//         element.style.display = "flex";
//     }
// }

